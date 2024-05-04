flatten_plans = Rewrite(Postwalk(Fixpoint(Chain([
    (@rule plan(~a1..., plan(~b...), ~a2...) => plan(a1..., b..., a2...)),
]))))

isolate_aggregates = Rewrite(Postwalk(
    @rule aggregate(~op, ~init, ~arg, ~idxs...) => begin
        name = alias(gensym(:A))
        subquery(name, aggregate(~op, ~init, ~arg, ~idxs...))
    end
))

isolate_reformats = Rewrite(Postwalk(
    @rule reformat(~tns, ~arg) => begin
        name = alias(gensym(:A))
        subquery(name, reformat(tns, arg))
    end
))

isolate_tables = Rewrite(Postwalk(
    @rule table(~tns, ~idxs...) => begin
        name = alias(gensym(:A))
        subquery(name, table(tns, idxs...))
    end
))


function lift_subqueries_expr(node::LogicNode, bindings)
    if node.kind === subquery
        if !haskey(bindings, node.lhs)
            arg_2 = lift_subqueries_expr(node.arg, bindings)
            bindings[node.lhs] = arg_2
        end
        node.lhs
    elseif istree(node)
        similarterm(node, operation(node), map(n -> lift_subqueries_expr(n, bindings), arguments(node)))
    else
        node
    end
end

"""
    lift_subqueries

Creates a plan that lifts all subqueries to the top level of the program, with
unique queries for each distinct subquery alias. This function processes the rhs
of each subquery once, to carefully extract SSA form from any nested pointer
structure. After calling lift_subqueries, it is safe to map over the program
(recursive pointers to subquery structures will not incur exponential overhead).
"""
function lift_subqueries(node::LogicNode)
    if node.kind === plan
        plan(map(lift_subqueries, node.bodies))
    elseif node.kind === query
        bindings = OrderedDict()
        rhs_2 = lift_subqueries_expr(node.rhs, bindings)
        plan(map(((lhs, rhs),) -> query(lhs, rhs), collect(bindings)), query(node.lhs, rhs_2))
    elseif node.kind === produces
        node
    else
        error()
    end
end

function pretty_labels(root)
    fields = Dict()
    aliases = Dict()
    Rewrite(Postwalk(Chain([
        (@rule ~i::isfield => get!(fields, i, field(Symbol(:i, length(fields))))),
        (@rule ~a::isalias => get!(aliases, a, alias(Symbol(:A, length(aliases))))),
    ])))(root)
end

"""
push_fields(node)

This program modifies all `EXPR` statements in the program, as
defined in the following grammar:
```
    LEAF := relabel(ALIAS, FIELD...) |
            table(IMMEDIATE, FIELD...) |
            IMMEDIATE
    EXPR := LEAF |
            reorder(EXPR, FIELD...) |
            relabel(EXPR, FIELD...) |
            mapjoin(IMMEDIATE, EXPR...)
```

Pushes all reorder and relabel statements down to LEAF nodes of each EXPR.
Output LEAF nodes will match the form `reorder(relabel(LEAF, FIELD...),
FIELD...)`, omitting reorder or relabel if not present as an ancestor of the
LEAF in the original EXPR. Tables and immediates will absorb relabels.
"""
function push_fields(root)
    root = Rewrite(Prewalk(Fixpoint(Chain([
        (@rule relabel(mapjoin(~op, ~args...), ~idxs...) => begin
            idxs_2 = getfields(mapjoin(op, args...))
            mapjoin(op, map(arg -> relabel(reorder(arg, idxs_2...), idxs...), args)...)
        end),
        (@rule relabel(relabel(~arg, ~idxs...), ~idxs_2...) =>
            relabel(~arg, ~idxs_2...)),
        (@rule relabel(reorder(~arg, ~idxs_1...), ~idxs_2...) => begin
            idxs_3 = getfields(arg)
            reidx = Dict(map(Pair, idxs_1, idxs_2)...)
            idxs_4 = map(idx -> get(reidx, idx, idx), idxs_3)
            reorder(relabel(arg, idxs_4...), idxs_2...)
        end),
        (@rule relabel(table(~arg, ~idxs_1...), ~idxs_2...) => begin
            table(arg, idxs_2...)
        end),
        (@rule relabel(~arg::isimmediate) => arg),
    ]))))(root)
    root = Rewrite(Prewalk(Fixpoint(Chain([
        (@rule reorder(mapjoin(~op, ~args...), ~idxs...) =>
            mapjoin(op, map(arg -> reorder(arg, ~idxs...), args)...)),
        (@rule reorder(reorder(~arg, ~idxs...), ~idxs_2...) =>
            reorder(~arg, ~idxs_2...)),
    ]))))(root)
    root
end

"""
propagate_transpose_queries(root)

Removes non-materializing permutation queries by propagating them to the
expressions they contain. Pushes fields and also removes copies. Removes queries of the form:
```
    query(ALIAS, reorder(relabel(ALIAS, FIELD...), FIELD...))
```

Does not remove queries which define production aliases.

Accepts programs of the form:
```
       TABLE  := table(IMMEDIATE, FIELD...)
       ACCESS := reorder(relabel(ALIAS, FIELD...), FIELD...)
    POINTWISE := ACCESS | mapjoin(IMMEDIATE, POINTWISE...) | reorder(IMMEDIATE, FIELD...) | IMMEDIATE
    MAPREDUCE := POINTWISE | aggregate(IMMEDIATE, IMMEDIATE, POINTWISE, FIELD...)
  INPUT_QUERY := query(ALIAS, TABLE)
COMPUTE_QUERY := query(ALIAS, reformat(IMMEDIATE, MAPREDUCE)) | query(ALIAS, MAPREDUCE))
         PLAN := plan(STEP...)
         STEP := COMPUTE_QUERY | INPUT_QUERY | PLAN | produces(ALIAS...)
         ROOT := STEP
```
"""
function propagate_transpose_queries(root::LogicNode)
    return propagate_transpose_queries_impl(root, getproductions(root), Dict{LogicNode, LogicNode}())
end

function propagate_transpose_queries_impl(node, productions, bindings)
    if @capture node plan(~stmts...)
        stmts = map(stmts) do stmt
            propagate_transpose_queries_impl(stmt, productions, bindings)
        end
        plan(stmts...)
    elseif @capture node query(~lhs, ~rhs)
        rhs = push_fields(Rewrite(Postwalk((node) -> get(bindings, node, node)))(rhs))
        if lhs in productions
            query(lhs, rhs)
        else
            if @capture rhs reorder(relabel(~rhs::isalias, ~idxs_1...), ~idxs_2...)
                bindings[lhs] = rhs
                plan()
            elseif @capture rhs relabel(~rhs::isalias, ~idxs_1...)
                bindings[lhs] = rhs
                plan()
            elseif isalias(rhs)
                bindings[lhs] = rhs
                plan()
            else
                query(lhs, rhs)
            end
        end
    elseif @capture node produces(~args...)
        node
    else
        throw(ArgumentError("Unrecognized program in propagate_transpose_queries"))
    end
end

function propagate_copy_queries(root)
    copies = Dict()
    for node in PostOrderDFS(root)
        if @capture node query(~a, ~b::isalias)
            copies[a] = get(copies, b, b)
        end
    end
    Rewrite(Postwalk(Chain([
        (a -> get(copies, a, nothing)),
        (@rule query(~a, ~a) => plan()),
    ])))(root)
end

"""
This one is a placeholder that places reorder statements inside aggregate and mapjoin query nodes.
only works on the output of propagate_fields(push_fields(prgm))
"""
function lift_fields(prgm)
    Rewrite(Postwalk(Chain([
        (@rule aggregate(~op, ~init, ~arg, ~idxs_1...) => begin
            idxs_2 = getfields(arg)
            aggregate(op, init, reorder(arg, idxs_2...), idxs_1...)
        end),
        (@rule query(~lhs, ~rhs) => if rhs.kind === mapjoin
            idxs = getfields(rhs)
            query(lhs, reorder(rhs, idxs...))
        end),
        (@rule query(~lhs, reformat(~arg)) => if arg.kind === mapjoin
            idxs = getfields(arg)
            query(lhs, reformat(reorder(arg, idxs...)))
        end),
    ])))(prgm)
end

pad_labels = Rewrite(Postwalk(
    @rule relabel(~arg, ~idxs...) => reorder(relabel(~arg, ~idxs...), idxs...)
))

function propagate_into_reformats(root)
    Rewrite(Postwalk(Chain([
        (@rule plan(~a1..., query(~b, ~c), ~a2..., query(~d, reformat(~tns, ~b)), ~a3...) => begin
            if !(b in PostOrderDFS(plan(a2..., a3...))) && (c.kind === mapjoin || c.kind === aggregate || c.kind === reorder)
                plan(a1..., query(d, reformat(tns, c)), a2..., a3...)
            end
        end),
    ])))(root)
end

function issubsequence(a, b)
    a = collect(a)
    b = collect(b)
    return issubset(a, b) && intersect(b, a) == a
end

function withsubsequence(a, b)
    a = collect(a)
    b = collect(b)
    view(b, findall(idx -> idx in a, b)) .= a
    b
end

"""
    concordize(root)

Accepts a program of the following form:

```
        TABLE := table(IMMEDIATE, FIELD...)
       ACCESS := reorder(relabel(ALIAS, FIELD...), FIELD...)
      COMPUTE := ACCESS |
                 mapjoin(IMMEDIATE, COMPUTE...) |
                 aggregate(IMMEDIATE, IMMEDIATE, COMPUTE, FIELD...) |
                 reformat(IMMEDIATE, COMPUTE) |
                 IMMEDIATE
COMPUTE_QUERY := query(ALIAS, COMPUTE)
  INPUT_QUERY := query(ALIAS, TABLE)
         STEP := COMPUTE_QUERY | INPUT_QUERY | produces(ALIAS...)
         ROOT := PLAN(STEP...)
```   

Inserts permutation statements of the form `query(ALIAS, reorder(ALIAS,
FIELD...))` and updates `relabel`s so that
they match their containing `reorder`s. Modified `ACCESS` statements match the form:

```
ACCESS := reorder(relabel(ALIAS, idxs_1::FIELD...), idxs_2::FIELD...) where issubsequence(idxs_1, idxs_2)
```
"""
function concordize(root)
    needed_swizzles = Dict()
    spc = Namespace()
    map(node->freshen(spc, node.name), unique(filter(Or(isfield, isalias), collect(PostOrderDFS(root)))))
    #Collect the needed swizzles
    root = Rewrite(Postwalk(
        @rule reorder(relabel(~a::isalias, ~idxs_1...), ~idxs_2...) => begin
            idxs_3 = intersect(idxs_1, idxs_2)
            if !issubsequence(idxs_3, idxs_2)
                idxs_4 = withsubsequence(intersect(idxs_2, idxs_1), idxs_1)
                perm = map(idx -> findfirst(isequal(idx), idxs_1), idxs_4)
                reorder(relabel(get!(get!(needed_swizzles, a, OrderedDict()), perm, alias(freshen(spc, a.name))), idxs_4), idxs_2...)
            end
        end
    ))(root)
    #Insert the swizzles
    root = Rewrite(Postwalk(Chain([
        (@rule query(~a, ~b) => begin
            if haskey(needed_swizzles, a)
                idxs = getfields(b)
                swizzle_queries = map(collect(needed_swizzles[a])) do (perm, c)
                    query(c, reorder(relabel(a, idxs...), idxs[perm]...))
                end
                plan(query(a, b), swizzle_queries...)
            end
        end),
    ])))(root)
    root = flatten_plans(root)
end

drop_noisy_reorders = Rewrite(Postwalk(
    @rule reorder(relabel(~arg, ~idxs...), ~idxs...) => relabel(arg, idxs...)
))

function format_queries(node::LogicNode, defer = false, bindings=Dict())
    if @capture node plan(~stmts...)
        stmts = map(stmts) do stmt
            format_queries(stmt, defer, bindings)
        end
        plan(stmts...)
    elseif (@capture node query(~lhs, ~rhs)) && rhs.kind !== reformat && rhs.kind !== table
        rep = SuitableRep(bindings)(rhs)
        bindings[lhs] = rep
        if defer
            tns = deferred(fiber_ctr(rep), typeof(rep_construct(rep)))
        else
            tns = immediate(rep_construct(rep))
        end
        query(lhs, reformat(tns, rhs))
    elseif @capture node query(~lhs, ~rhs)
        bindings[lhs] = SuitableRep(bindings)(rhs)
        node
    else
        node
    end
end
struct SuitableRep
    bindings::Dict
end
function (ctx::SuitableRep)(ex)
    if ex.kind === alias
        return ctx.bindings[ex]
    elseif @capture ex table(~tns::isimmediate, ~idxs...)
        return data_rep(ex.tns.val)
    elseif @capture ex table(~tns::isdeferred, ~idxs...)
        return data_rep(ex.tns.type)
    elseif ex.kind === mapjoin
        #This step assumes concordant mapjoin arguments, and also that the
        #mapjoin arguments have the same number of dimensions. It's necessary to
        #assume this because it's not possible to recursively reconstruct a
        #total ordering of the indices as we go.
        return map_rep(ex.op.val, map(ctx, ex.args)...)
    elseif ex.kind === aggregate
        idxs = getfields(ex.arg)
        return aggregate_rep(ex.op.val, ex.init.val, ctx(ex.arg), map(idx->findfirst(isequal(idx), idxs), ex.idxs))
    elseif ex.kind === reorder
        #In this step, we need to consider that the reorder may add or permute
        #dims. I haven't considered whether this is robust to dropping dims (it
        #probably isn't)
        idxs = getfields(ex.arg)
        perm = sortperm(idxs, by=idx->findfirst(isequal(idx), ex.idxs))
        rep = permutedims_rep(ctx(ex.arg), perm)
        dims = findall(idx -> idx in idxs, ex.idxs)
        return extrude_rep(rep, dims)
    elseif ex.kind === relabel
        return ctx(ex.arg)
    elseif ex.kind === reformat
        return data_rep(ex.tns.val)
    elseif ex.kind === immediate
        return ElementData(ex.val, typeof(ex.val))
    else
        error("Unrecognized expression: $(ex.kind)")
    end
end

"""
    FinchInterpreter

The finch interpreter is a simple interpreter for finch logic programs. The interpreter is
only capable of executing programs of the form:
      REORDER := reorder(relabel(ALIAS, FIELD...), FIELD...)
       ACCESS := reorder(relabel(ALIAS, idxs_1::FIELD...), idxs_2::FIELD...) where issubsequence(idxs_1, idxs_2)
    POINTWISE := ACCESS | mapjoin(IMMEDIATE, POINTWISE...) | reorder(IMMEDIATE, FIELD...) | IMMEDIATE
    MAPREDUCE := POINTWISE | aggregate(IMMEDIATE, IMMEDIATE, POINTWISE, FIELD...)
       TABLE  := table(IMMEDIATE, FIELD...)
COMPUTE_QUERY := query(ALIAS, reformat(IMMEDIATE, arg::(REORDER | MAPREDUCE)))
  INPUT_QUERY := query(ALIAS, TABLE)
         STEP := COMPUTE_QUERY | INPUT_QUERY | produces(ALIAS...)
         ROOT := PLAN(STEP...)
"""
struct FinchInterpreter
    scope::Dict
end

FinchInterpreter() = FinchInterpreter(Dict())

using Finch.FinchNotation: block_instance, declare_instance, call_instance, loop_instance, index_instance, variable_instance, tag_instance, access_instance, assign_instance, literal_instance, yieldbind_instance

function finch_pointwise_logic_to_program(scope, ex)
    if @capture ex mapjoin(~op, ~args...)
        call_instance(literal_instance(op.val), map(arg -> finch_pointwise_logic_to_program(scope, arg), args)...)
    elseif (@capture ex reorder(relabel(~arg::isalias, ~idxs_1...), ~idxs_2...))
        idxs_3 = map(enumerate(idxs_1)) do (n, idx)
            idx in idxs_2 ? index_instance(idx.name) : first(axes(arg)[n])
        end
        access_instance(tag_instance(variable_instance(arg.name), scope[arg]), literal_instance(reader), idxs_3...)
    elseif (@capture ex reorder(~arg::isimmediate, ~idxs...))
        literal_instance(arg.val)
    elseif ex.kind === immediate
        literal_instance(ex.val)
    else
        error("Unrecognized logic: $(ex)")
    end
end

function (ctx::FinchInterpreter)(ex)
    if ex.kind === alias
        ex.scope[ex]
    elseif @capture ex query(~lhs, ~rhs)
        ctx.scope[lhs] = ctx(rhs)
        (ctx.scope[lhs],)
    elseif @capture ex table(~tns, ~idxs...)
        return tns.val
    elseif @capture ex reformat(~tns, reorder(relabel(~arg::isalias, ~idxs_1...), ~idxs_2...))
        loop_idxs = map(idx -> index_instance(idx.name), withsubsequence(intersect(idxs_1, idxs_2), idxs_2))
        lhs_idxs = map(idx -> index_instance(idx.name), idxs_2)
        res = tag_instance(variable_instance(:res), tns.val)
        lhs = access_instance(res, literal_instance(updater), lhs_idxs...)
        rhs = finch_pointwise_logic_to_program(ctx.scope, reorder(relabel(arg, idxs_1...), idxs_2...))
        body = assign_instance(lhs, literal_instance(initwrite(default(tns.val))), rhs)
        for idx in loop_idxs
            body = loop_instance(idx, dimless, body)
        end
        body = block_instance(declare_instance(res, literal_instance(default(tns.val))), body, yieldbind_instance(res))
        #display(body) # wow it's really satisfying to uncomment this and type finch ops at the repl.
        execute(body).res
    elseif @capture ex reformat(~tns, mapjoin(~args...))
        z = default(tns.val)
        ctx(reformat(tns, aggregate(initwrite(z), immediate(z), mapjoin(args...))))
    elseif @capture ex reformat(~tns, aggregate(~op, ~init, ~arg, ~idxs_1...))
        idxs_2 = map(idx -> index_instance(idx.name), getfields(arg))
        idxs_3 = map(idx -> index_instance(idx.name), setdiff(getfields(arg), idxs_1))
        res = tag_instance(variable_instance(:res), tns.val)
        lhs = access_instance(res, literal_instance(updater), idxs_3...)
        rhs = finch_pointwise_logic_to_program(ctx.scope, arg)
        body = assign_instance(lhs, literal_instance(op.val), rhs)
        for idx in idxs_2
            body = loop_instance(idx, dimless, body)
        end
        body = block_instance(declare_instance(res, literal_instance(default(tns.val))), body, yieldbind_instance(res))
        #display(body) # wow it's really satisfying to uncomment this and type finch ops at the repl.
        execute(body).res
    elseif @capture ex produces(~args...)
        return map(arg -> ctx.scope[arg], args)
    elseif @capture ex plan(~head)
        ctx(head)
    elseif @capture ex plan(~head, ~tail...)
        ctx(head)
        return ctx(plan(tail...))
    else
        error("Unrecognized logic: $(ex)")
    end
end

function normalize_names(ex)
    spc = Namespace()
    scope = Dict()
    normname(sym) = get!(scope, sym) do
        if isgensym(sym)
            sym = gensymname(sym)
        end
        freshen(spc, sym)
    end
    Rewrite(Postwalk(@rule ~a::isalias => alias(normname(a.name))))(ex)
end

"""
    lazy(arg)

Create a lazy tensor from an argument. All operations on lazy tensors are
lazy, and will not be executed until `compute` is called on their result.

for example,
```julia
x = lazy(rand(10))
y = lazy(rand(10))
z = x + y
z = z + 1
z = compute(z)
```
will not actually compute `z` until `compute(z)` is called, so the execution of `x + y`
is fused with the execution of `z + 1`.
"""
lazy(arg) = LazyTensor(arg)

function propagate_map_queries(root)
    root = Rewrite(Postwalk(@rule aggregate(~op, ~init, ~arg) => mapjoin(op, init, arg)))(root)
    rets = getproductions(root)
    props = Dict()
    for node in PostOrderDFS(root)
        if @capture node query(~a, mapjoin(~op, ~args...))
            if !(a in rets)
                props[a] = mapjoin(op, args...)
            end
        end
    end
    Rewrite(Prewalk(Chain([
        (a -> if haskey(props, a) props[a] end),
        (@rule query(~a, ~b) => if haskey(props, a) plan() end),
        (@rule plan(~a1..., plan(), ~a2...) => plan(a1..., a2...)),
    ])))(root)
end


function simple_map(::Type{T}, f::F, args) where {T, F}
    res = Vector{T}(undef, length(args))
    for i in 1:length(args)
        res[i] = f(args[i])
    end
    res
end

"""
    get_structure(root::LogicNode)

Quickly produce a normalized structure for a logic program. Note: the result
will not be a runnable logic program, but can be hashed and compared for
equality. Two programs will have equal structure if their tensors have the same
type and their program structure is equivalent up to renaming.
"""
function get_structure(
    node::LogicNode,
    fields::Dict{Symbol, LogicNode}=Dict{Symbol, LogicNode}(),
    aliases::Dict{Symbol, LogicNode}=Dict{Symbol, LogicNode}())
    if node.kind === field
        get!(fields, node.name, immediate(length(fields) + length(aliases)))
    elseif node.kind === alias
        get!(aliases, node.name, immediate(length(fields) + length(aliases)))
    elseif node.kind === subquery
        if haskey(aliases, node.lhs.name)
            names[node.lhs]
        else
            subquery(get_structure(node.lhs, fields, aliases), get_structure(node.arg, fields, aliases))
        end
    elseif node.kind === table
        table(immediate(typeof(node.tns.val)), simple_map(LogicNode, idx -> get_structure(idx, fields, aliases), node.idxs))
    elseif istree(node)
        similarterm(node, operation(node), simple_map(LogicNode, arg -> get_structure(arg, fields, aliases), arguments(node)))
    else
        node
    end
end

"""
    FinchCompiler

The finch compiler is a simple compiler for finch logic programs. The interpreter is
only capable of executing programs of the form:
      REORDER := reorder(relabel(ALIAS, FIELD...), FIELD...)
       ACCESS := reorder(relabel(ALIAS, idxs_1::FIELD...), idxs_2::FIELD...) where issubsequence(idxs_1, idxs_2)
    POINTWISE := ACCESS | mapjoin(IMMEDIATE, POINTWISE...) | reorder(IMMEDIATE, FIELD...) | IMMEDIATE
    MAPREDUCE := POINTWISE | aggregate(IMMEDIATE, IMMEDIATE, POINTWISE, FIELD...)
       TABLE  := table(IMMEDIATE | DEFERRED, FIELD...)
COMPUTE_QUERY := query(ALIAS, reformat(IMMEDIATE, arg::(REORDER | MAPREDUCE)))
  INPUT_QUERY := query(ALIAS, TABLE)
         STEP := COMPUTE_QUERY | INPUT_QUERY | produces(ALIAS...)
         ROOT := PLAN(STEP...)
"""
struct FinchCompiler end

function finch_pointwise_logic_to_code(ex)
    if @capture ex mapjoin(~op, ~args...)
        :($(op.val)($(map(arg -> finch_pointwise_logic_to_code(arg), args)...)))
    elseif (@capture ex reorder(relabel(~arg::isalias, ~idxs_1...), ~idxs_2...))
        :($(arg.name)[$(map(idx -> idx.name, idxs_1)...)])
    elseif (@capture ex reorder(~arg::isimmediate, ~idxs...))
        arg.val
    elseif ex.kind === immediate
        ex.val
    else
        error("Unrecognized logic: $(ex)")
    end
end

function compile_logic_constant(node)
    if node.kind === immediate
        node.val
    elseif node.kind === deferred
        :($(node.ex)::$(node.type))
    else
        error()
    end
end

function logic_constant_type(node)
    if node.kind === immediate
        typeof(node.val)
    elseif node.kind === deferred
        node.type
    else
        error()
    end
end

function (ctx::FinchCompiler)(ex)
    if @capture ex query(~lhs::isalias, table(~tns, ~idxs...))
        :($(lhs.name) = $(compile_logic_constant(tns)))
    elseif @capture ex query(~lhs::isalias, reformat(~tns, reorder(relabel(~arg::isalias, ~idxs_1...), ~idxs_2...)))
        loop_idxs = map(idx -> idx.name, withsubsequence(intersect(idxs_1, idxs_2), idxs_2))
        lhs_idxs = map(idx -> idx.name, idxs_2)
        rhs = finch_pointwise_logic_to_code(reorder(relabel(arg, idxs_1...), idxs_2...))
        body = :($(lhs.name)[$(lhs_idxs...)] = $rhs)
        for idx in loop_idxs
            body = :(for $idx = _
                $body
            end)
        end
        quote
            $(lhs.name) = $(compile_logic_constant(tns))
            @finch begin
                $(lhs.name) .= $(default(logic_constant_type(tns)))
                $body
                return $(lhs.name)
            end
        end
    elseif @capture ex query(~lhs::isalias, reformat(~tns, mapjoin(~args...)))
        z = default(logic_constant_type(tns))
        ctx(query(lhs, reformat(tns, aggregate(initwrite(z), immediate(z), mapjoin(args...)))))
    elseif @capture ex query(~lhs, reformat(~tns, aggregate(~op, ~init, ~arg, ~idxs_1...)))
        idxs_2 = map(idx -> idx.name, getfields(arg))
        idxs_3 = map(idx -> idx.name, setdiff(getfields(arg), idxs_1))
        rhs = finch_pointwise_logic_to_code(arg)
        body = :($(lhs.name)[$(idxs_3...)] <<$(compile_logic_constant(op))>>= $rhs)
        for idx in idxs_2
            body = :(for $idx = _
                $body
            end)
        end
        quote
            $(lhs.name) = $(compile_logic_constant(tns))
            @finch begin
                $(lhs.name) .= $(default(logic_constant_type(tns)))
                $body
                return $(lhs.name)
            end
        end
    elseif @capture ex produces(~args...)
        return :(return ($(map(arg -> arg.name, args)...),))
    elseif @capture ex plan(~bodies...)
        Expr(:block, map(ctx, bodies)...)
    else
        error("Unrecognized logic: $(ex)")
    end
end

"""
    defer_tables(root::LogicNode)

Replace immediate tensors with deferred expressions assuming the original program structure
is given as input to the program.
"""
function defer_tables(ex, node::LogicNode)
    if @capture node table(~tns::isimmediate, ~idxs...)
        table(deferred(:($ex.tns.val), typeof(tns.val)), map(enumerate(node.idxs)) do (i, idx)
            defer_tables(:($ex.idxs[$i]), idx)
        end)
    elseif istree(node)
        similarterm(node, operation(node), map(enumerate(node.children)) do (i, child)
            defer_tables(:($ex.children[$i]), child)
        end)
    else
        node
    end
end

"""
    cache_deferred(ctx, root::LogicNode, seen)

Replace deferred expressions with simpler expressions, and cache their evaluation in the preamble.
"""
function cache_deferred!(ctx, root::LogicNode)
    seen::Dict{Any, LogicNode} = Dict{Any, LogicNode}()
    return Rewrite(Postwalk(node -> if isdeferred(node)
        get!(seen, node.val) do
            var = freshen(ctx, :V)
            push!(ctx.preamble, :($var = $(node.ex)::$(node.type)))
            deferred(var, node.type)
        end
    end))(root)
end

function compile(prgm::LogicNode)
    ctx = JuliaContext()
    freshen(ctx, :prgm)
    code = contain(ctx) do ctx_2
        prgm = defer_tables(:prgm, prgm)
        prgm = cache_deferred!(ctx_2, prgm)
        prgm = optimize(prgm)
        prgm = format_queries(prgm, true)
        FinchCompiler()(prgm)
    end
    code = pretty(code)
    fname = gensym(:compute)
    return :(function $fname(prgm)
            $code
        end) |> striplines
end

codes = Dict()
function compute_impl(prgm, ::FinchCompiler)
    f = get!(codes, get_structure(prgm)) do
        eval(compile(prgm))
    end
    return Base.invokelatest(f, prgm)
end

struct DefaultOptimizer
    ctx
end

default_optimizer = DefaultOptimizer(FinchCompiler())

"""
    compute(args..., ctx=default_optimizer) -> Any

Compute the value of a lazy tensor. The result is the argument itself, or a
tuple of arguments if multiple arguments are passed.
"""
compute(args...; ctx=default_optimizer) = compute_parse(args, ctx)
compute(arg; ctx=default_optimizer) = compute_parse((arg,), ctx)[1]
compute(args::Tuple; ctx=default_optimizer) = compute_parse(args, ctx)
function compute_parse(args::Tuple, ctx)
    args = collect(args)
    vars = map(arg -> alias(gensym(:A)), args)
    bodies = map((arg, var) -> query(var, arg.data), args, vars)
    prgm = plan(bodies, produces(vars))

    return compute_impl(prgm, ctx)
end

"""
compute(args..., ctx = ctx) = 

FinchInterpreter(DefaultOptimizer())(prgm)
FinchInterpreter(DefaultNormalizer(DefaultHeuristic()))(prgm)
FinchInterpreter(DefaultNormalizer())(prgm)
FinchCompiler(DefaultNormalizer())(prgm)
FinchExecutor(FinchCompiler(DefaultNormalizer()))(prgm)
FinchExecutor(ChipCacher(FinchCompiler(DefaultNormalizer())))(prgm)
FinchExecutor(ChipCacher(FinchCompiler(DefaultNormalizer())))(prgm)
"""

function compute_impl(prgm, ctx::DefaultOptimizer)
    compute_impl(prgm, ctx.ctx)
end

function compute_impl(prgm, ctx::FinchInterpreter)
    prgm = optimize(prgm)
    prgm = format_queries(prgm)
    ctx(prgm)
end

function optimize(prgm)
    #deduplicate and lift inline subqueries to regular queries
    prgm = lift_subqueries(prgm)

    #At this point in the program, all statements should be unique, so
    #it is okay to name different occurences of things.

    #these steps lift reformat, aggregate, and table nodes into separate
    #queries, using subqueries as temporaries.
    prgm = isolate_reformats(prgm)
    prgm = isolate_aggregates(prgm)
    prgm = isolate_tables(prgm)
    prgm = lift_subqueries(prgm)

    #I shouldn't use gensym but I do, so this cleans up the names
    prgm = pretty_labels(prgm)

    #@info "split"
    #display(prgm)

    #These steps fuse copy, permutation, and mapjoin statements
    #into later expressions.
    #Only reformat statements preserve intermediate breaks in computation
    prgm = propagate_copy_queries(prgm)
    prgm = propagate_transpose_queries(prgm)
    prgm = propagate_map_queries(prgm)

    #@info "fused"
    #display(prgm)

    #These steps assign a global loop order to each statement.
    prgm = propagate_fields(prgm)

    #@info "propagate_fields"
    #display(prgm)

    prgm = push_fields(prgm)
    prgm = lift_fields(prgm)
    prgm = push_fields(prgm)

    #@info "loops ordered"
    #display(prgm)

    #After we have a global loop order, we concordize the program
    prgm = concordize(prgm)

    #@info "concordized"
    #display(prgm)

    #Add reformat statements where there aren't any
    prgm = propagate_into_reformats(prgm)
    prgm = propagate_copy_queries(prgm)
    #Normalize names for caching
    prgm = normalize_names(prgm)

    #@info "formatted"
    #display(prgm)

end