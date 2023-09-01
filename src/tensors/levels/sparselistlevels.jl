"""
    SparseListLevel{[Ti=Int], [Tp=Int]}(lvl, [dim])

A subfiber of a sparse level does not need to represent slices `A[:, ..., :, i]`
which are entirely [`default`](@ref). Instead, only potentially non-default
slices are stored as subfibers in `lvl`.  A sorted list is used to record which
slices are stored. Optionally, `dim` is the size of the last dimension.

`Ti` is the type of the last fiber index, and `Tp` is the type used for
positions in the level.

In the [`Fiber!`](@ref) constructor, `sl` is an alias for `SparseListLevel`.

```jldoctest
julia> Fiber!(Dense(SparseList(Element(0.0))), [10 0 20; 30 0 0; 0 0 40])
Dense [:,1:3]
├─[:,1]: SparseList (0.0) [1:3]
│ ├─[1]: 10.0
│ ├─[2]: 30.0
├─[:,2]: SparseList (0.0) [1:3]
├─[:,3]: SparseList (0.0) [1:3]
│ ├─[1]: 20.0
│ ├─[3]: 40.0

julia> Fiber!(SparseList(SparseList(Element(0.0))), [10 0 20; 30 0 0; 0 0 40])
SparseList (0.0) [:,1:3]
├─[:,1]: SparseList (0.0) [1:3]
│ ├─[1]: 10.0
│ ├─[2]: 30.0
├─[:,3]: SparseList (0.0) [1:3]
│ ├─[1]: 20.0
│ ├─[3]: 40.0

```
"""
struct SparseListLevel{Ti, Tp, VTp<:AbstractVector, VTi<:AbstractVector, Lvl}
    lvl::Lvl
    shape::Ti
    ptr::VTp
    idx::VTi
end
const SparseList = SparseListLevel
SparseListLevel(lvl::Lvl) where {Lvl} = SparseListLevel{indextype(Lvl)}(lvl)
SparseListLevel(lvl, shape, args...) = SparseListLevel{typeof(shape)}(lvl, shape, args...)
SparseListLevel{Ti}(lvl, args...) where {Ti} = SparseListLevel{Ti, postype(typeof(lvl))}(lvl, args...)
SparseListLevel{Ti, Tp}(lvl, args...) where {Ti, Tp} =
    SparseListLevel{Ti, Tp, memory_type(typeof(lvl)){Tp, 1}, memory_type(typeof(lvl)){Ti, 1}, typeof(lvl)}(lvl, args...)

SparseListLevel{Ti, Tp, VTp, VTi, Lvl}(lvl) where {Ti, Tp, VTp, VTi, Lvl} = SparseListLevel{Ti, Tp, VTp, VTi, Lvl}(lvl, zero(Ti))
SparseListLevel{Ti, Tp, VTp, VTi, Lvl}(lvl, shape) where {Ti, Tp, VTp, VTi, Lvl} = 
    SparseListLevel{Ti, Tp, VTp, VTi, Lvl}(lvl, Ti(shape), single(memory_type(Lvl){Ti, 1}), empty(memory_type(Lvl){Tp, 1}))

SparseListLevel{Ti, Tp, Lvl}(lvl, shape, ptr, idx) where {Ti, Tp, Lvl} = 
    SparseListLevel{Ti, Tp, typeof(ptr), typeof(idx), Lvl}(lvl, Ti(shape), ptr, idx)
    
Base.summary(lvl::SparseListLevel) = "SparseList($(summary(lvl.lvl)))"
similar_level(lvl::SparseListLevel) = SparseList(similar_level(lvl.lvl))
similar_level(lvl::SparseListLevel, dim, tail...) = SparseList(similar_level(lvl.lvl, tail...), dim)

function memory_type(::Type{SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}) where {Ti, Tp, Lvl, VTi, VTp}
    return containertype(VTp)
end

function postype(::Type{SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}) where {Ti, Tp, Lvl, VTi, VTp}
    return Tp
end

function indextype(::Type{SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}) where {Ti, Tp, Lvl, VTi, VTp}
    return indextype(Ti)
end

function moveto(lvl::SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}, ::Type{MemType}) where {Ti, Tp, Lvl, VTi, VTp, MemType <: AbstractVector}
    lvl_2 = moveto(lvl.lvl, MemType)
    ptr_2 = MemType{Tp, 1}(lvl.ptr)
    idx_2 = MemType{Ti, 1}(lvl.idx)
    return SparseListLevel{Ti, Tp, typeof(lvl_2), MemType{Ti, 1}, MemType{Tp, 1}}(lvl_2, lvl.shape, ptr_2, idx_2)
end



function countstored_level(lvl::SparseListLevel, pos)
    countstored_level(lvl.lvl, lvl.ptr[pos + 1] - 1)
end

pattern!(lvl::SparseListLevel{Ti, Tp}) where {Ti, Tp} = 
    SparseListLevel{Ti, Tp}(pattern!(lvl.lvl), lvl.shape, lvl.ptr, lvl.idx)

redefault!(lvl::SparseListLevel{Ti, Tp}, init) where {Ti, Tp} = 
    SparseListLevel{Ti, Tp}(redefault!(lvl.lvl, init), lvl.shape, lvl.ptr, lvl.idx)

function Base.show(io::IO, lvl::SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}) where {Ti, Tp, Lvl, VTi, VTp}
    if get(io, :compact, false)
        print(io, "SparseList(")
    else
        print(io, "SparseList{$Ti, $Tp}(")
    end
    show(io, lvl.lvl)
    print(io, ", ")
    show(IOContext(io, :typeinfo=>Ti), lvl.shape)
    print(io, ", ")
    if get(io, :compact, false)
        print(io, "…")
    else
        show(IOContext(io, :typeinfo=>VTp), lvl.ptr)
        print(io, ", ")
        show(IOContext(io, :typeinfo=>VTi), lvl.idx)
    end
    print(io, ")")
end

function display_fiber(io::IO, mime::MIME"text/plain", fbr::SubFiber{<:SparseListLevel}, depth)
    p = fbr.pos
    crds = @view(fbr.lvl.idx[fbr.lvl.ptr[p]:fbr.lvl.ptr[p + 1] - 1])

    print_coord(io, crd) = show(io, crd)
    get_fbr(crd) = fbr(crd)

    print(io, "SparseList (", default(fbr), ") [", ":,"^(ndims(fbr) - 1), "1:", fbr.lvl.shape, "]")
    display_fiber_data(io, mime, fbr, depth, 1, crds, print_coord, get_fbr)
end

@inline level_ndims(::Type{<:SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}) where {Ti, Tp,  VTp, VTi, Lvl} = 1 + level_ndims(Lvl)
@inline level_size(lvl::SparseListLevel) = (level_size(lvl.lvl)..., lvl.shape)
@inline level_axes(lvl::SparseListLevel) = (level_axes(lvl.lvl)..., Base.OneTo(lvl.shape))
@inline level_eltype(::Type{<:SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}) where {Ti, Tp,  VTp, VTi, Lvl} = level_eltype(Lvl)
@inline level_default(::Type{<:SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}) where {Ti, Tp,  VTp, VTi, Lvl} = level_default(Lvl)
data_rep_level(::Type{<:SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}) where {Ti, Tp,  VTp, VTi, Lvl} = SparseData(data_rep_level(Lvl))

(fbr::AbstractFiber{<:SparseListLevel})() = fbr
function (fbr::SubFiber{<:SparseListLevel{Ti}})(idxs...) where {Ti}
    isempty(idxs) && return fbr
    lvl = fbr.lvl
    p = fbr.pos
    r = searchsorted(@view(lvl.idx[lvl.ptr[p]:lvl.ptr[p + 1] - 1]), idxs[end])
    q = lvl.ptr[p] + first(r) - 1
    fbr_2 = SubFiber(lvl.lvl, q)
    length(r) == 0 ? default(fbr_2) : fbr_2(idxs[1:end-1]...)
end

mutable struct VirtualSparseListLevel
    lvl
    ex
    Ti
    Tp
    shape
    qos_fill
    qos_stop
end
function virtualize(ex, ::Type{SparseListLevel{Ti, Tp,  VTp, VTi, Lvl}}, ctx, tag=:lvl) where {Ti, Tp, Lvl, VTi, VTp}
    sym = ctx.freshen(tag)
    shape = value(:($sym.shape), Int)
    qos_fill = ctx.freshen(sym, :_qos_fill)
    qos_stop = ctx.freshen(sym, :_qos_stop)
    push!(ctx.preamble, quote
        $sym = $ex
    end)
    lvl_2 = virtualize(:($sym.lvl), Lvl, ctx, sym)
    VirtualSparseListLevel(lvl_2, sym, Ti, Tp, shape, qos_fill, qos_stop)
end
function lower(lvl::VirtualSparseListLevel, ctx::AbstractCompiler, ::DefaultStyle)
    quote
        $SparseListLevel{$(lvl.Ti), $(lvl.Tp)}(
            $(ctx(lvl.lvl)),
            $(ctx(lvl.shape)),
            $(lvl.ex).ptr,
            $(lvl.ex).idx,
        )
    end
end

Base.summary(lvl::VirtualSparseListLevel) = "SparseList($(summary(lvl.lvl)))"

function virtual_level_size(lvl::VirtualSparseListLevel, ctx)
    ext = make_extent(lvl.Ti, literal(lvl.Ti(1)), lvl.shape)
    (virtual_level_size(lvl.lvl, ctx)..., ext)
end

function virtual_level_resize!(lvl::VirtualSparseListLevel, ctx, dims...)
    lvl.shape = getstop(dims[end])
    lvl.lvl = virtual_level_resize!(lvl.lvl, ctx, dims[1:end-1]...)
    lvl
end

virtual_level_eltype(lvl::VirtualSparseListLevel) = virtual_level_eltype(lvl.lvl)
virtual_level_default(lvl::VirtualSparseListLevel) = virtual_level_default(lvl.lvl)

function declare_level!(lvl::VirtualSparseListLevel, ctx::AbstractCompiler, pos, init)
    #TODO check that init == default
    Ti = lvl.Ti
    Tp = lvl.Tp
    qos = call(-, call(getindex, :($(lvl.ex).ptr), call(+, pos, 1)),  1)
    push!(ctx.preamble, quote
        $(lvl.qos_fill) = $(Tp(0))
        $(lvl.qos_stop) = $(Tp(0))
    end)
    lvl.lvl = declare_level!(lvl.lvl, ctx, qos, init)
    return lvl
end

function trim_level!(lvl::VirtualSparseListLevel, ctx::AbstractCompiler, pos)
    qos = ctx.freshen(:qos)
    push!(ctx.preamble, quote
        resize!($(lvl.ex).ptr, $(ctx(pos)) + 1)
        $qos = $(lvl.ex).ptr[end] - $(lvl.Tp(1))
        resize!($(lvl.ex).idx, $qos)
    end)
    lvl.lvl = trim_level!(lvl.lvl, ctx, value(qos, lvl.Tp))
    return lvl
end

function assemble_level!(lvl::VirtualSparseListLevel, ctx, pos_start, pos_stop)
    pos_start = ctx(cache!(ctx, :p_start, pos_start))
    pos_stop = ctx(cache!(ctx, :p_start, pos_stop))
    return quote
        Finch.resize_if_smaller!($(lvl.ex).ptr, $pos_stop + 1)
        Finch.fill_range!($(lvl.ex).ptr, 0, $pos_start + 1, $pos_stop + 1)
    end
end

function freeze_level!(lvl::VirtualSparseListLevel, ctx::AbstractCompiler, pos_stop)
    p = ctx.freshen(:p)
    pos_stop = ctx(cache!(ctx, :pos_stop, simplify(pos_stop, ctx)))
    qos_stop = ctx.freshen(:qos_stop)
    push!(ctx.preamble, quote
        for $p = 2:($pos_stop + 1)
            $(lvl.ex).ptr[$p] += $(lvl.ex).ptr[$p - 1]
        end
        $qos_stop = $(lvl.ex).ptr[$pos_stop + 1] - 1
    end)
    lvl.lvl = freeze_level!(lvl.lvl, ctx, value(qos_stop))
    return lvl
end

function instantiate_reader(fbr::VirtualSubFiber{VirtualSparseListLevel}, ctx, ::Union{typeof(defaultread), typeof(walk)}, protos...)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    tag = lvl.ex
    Tp = lvl.Tp
    Ti = lvl.Ti
    my_i = ctx.freshen(tag, :_i)
    my_q = ctx.freshen(tag, :_q)
    my_q_stop = ctx.freshen(tag, :_q_stop)
    my_i1 = ctx.freshen(tag, :_i1)

    Furlable(
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $my_q = $(lvl.ex).ptr[$(ctx(pos))]
                $my_q_stop = $(lvl.ex).ptr[$(ctx(pos)) + $(Tp(1))]
                if $my_q < $my_q_stop
                    $my_i = $(lvl.ex).idx[$my_q]
                    $my_i1 = $(lvl.ex).idx[$my_q_stop - $(Tp(1))]
                else
                    $my_i = $(Ti(1))
                    $my_i1 = $(Ti(0))
                end
            end,
            body = (ctx) -> Sequence([
                Phase(
                    stop = (ctx, ext) -> value(my_i1),
                    body = (ctx, ext) -> Stepper(
                        seek = (ctx, ext) -> quote
                            if $(lvl.ex).idx[$my_q] < $(ctx(getstart(ext)))
                                $my_q = Finch.scansearch($(lvl.ex).idx, $(ctx(getstart(ext))), $my_q, $my_q_stop - 1)
                            end
                        end,
                        body = Thunk(
                            preamble = quote
                                $my_i = $(lvl.ex).idx[$my_q]
                            end,
                            body = (ctx) -> Step(
                                stop = (ctx, ext) -> value(my_i),
                                chunk = Spike(
                                    body = Fill(virtual_level_default(lvl)),
                                    tail = Simplify(instantiate_reader(VirtualSubFiber(lvl.lvl, value(my_q, Ti)), ctx, protos...))
                                ),
                                next = (ctx, ext) -> quote
                                    $my_q += $(Tp(1))
                                end
                            )
                        )
                    )
                ),
                Phase(
                    body = (ctx, ext) -> Run(Fill(virtual_level_default(lvl)))
                )
            ])
        )
    )
end

function instantiate_reader(fbr::VirtualSubFiber{VirtualSparseListLevel}, ctx, ::typeof(gallop), protos...)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    tag = lvl.ex
    Tp = lvl.Tp
    Ti = lvl.Ti
    my_i = ctx.freshen(tag, :_i)
    my_q = ctx.freshen(tag, :_q)
    my_q_stop = ctx.freshen(tag, :_q_stop)
    my_i1 = ctx.freshen(tag, :_i1)
    my_i2 = ctx.freshen(tag, :_i2)
    my_i3 = ctx.freshen(tag, :_i3)
    my_i4 = ctx.freshen(tag, :_i4)

    Furlable(
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $my_q = $(lvl.ex).ptr[$(ctx(pos))]
                $my_q_stop = $(lvl.ex).ptr[$(ctx(pos)) + 1]
                if $my_q < $my_q_stop
                    $my_i = $(lvl.ex).idx[$my_q]
                    $my_i1 = $(lvl.ex).idx[$my_q_stop - $(Tp(1))]
                else
                    $my_i = $(Ti(1))
                    $my_i1 = $(Ti(0))
                end
            end,
            body = (ctx) -> Sequence([
                Phase(
                    stop = (ctx, ext) -> value(my_i1),
                    body = (ctx, ext) -> Jumper(
                        body = Thunk(
                            body = (ctx) -> Jump(
                                seek = (ctx, ext) -> quote
                                    if $(lvl.ex).idx[$my_q] < $(ctx(getstart(ext)))
                                        $my_q = Finch.scansearch($(lvl.ex).idx, $(ctx(getstart(ext))), $my_q, $my_q_stop - 1)
                                    end
                                    $my_i2 = $(lvl.ex).idx[$my_q]
                                end,
                                stop = (ctx, ext) -> value(my_i2),
                                body = (ctx, ext, ext_2) -> Switch([
                                    value(:($(ctx(getstop(ext_2))) == $my_i2)) => Thunk(
                                        body = (ctx) -> Spike(
                                            body = Fill(virtual_level_default(lvl)),
                                            tail = instantiate_reader(VirtualSubFiber(lvl.lvl, value(my_q, Ti)), ctx, protos...),
                                        ),
                                        epilogue = quote
                                            $my_q += $(Tp(1))
                                        end
                                    ),
                                    literal(true) => Stepper(
                                        seek = (ctx, ext) -> quote
                                            if $(lvl.ex).idx[$my_q] < $(ctx(getstart(ext)))
                                                $my_q = Finch.scansearch($(lvl.ex).idx, $(ctx(getstart(ext))), $my_q, $my_q_stop - 1)
                                            end
                                        end,
                                        body = Thunk(
                                            preamble = :(
                                                $my_i3 = $(lvl.ex).idx[$my_q]
                                            ),
                                            body = (ctx) -> Step(
                                                stop = (ctx, ext) -> value(my_i3),
                                                chunk = Spike(
                                                    body = Fill(virtual_level_default(lvl)),
                                                    tail =  instantiate_reader(VirtualSubFiber(lvl.lvl, value(my_q, Ti)), ctx, protos...),
                                                ),
                                                next = (ctx, ext) -> quote
                                                    $my_q += $(Tp(1))
                                                end
                                            )
                                        )
                                    ),
                                ])
                            )
                        )
                    )
                ),
                Phase(
                    body = (ctx, ext) -> Run(Fill(virtual_level_default(lvl)))
                )
            ])
        )
    )
end

is_laminable_updater(lvl::VirtualSparseListLevel, ctx, protos...) = false
instantiate_updater(fbr::VirtualSubFiber{VirtualSparseListLevel}, ctx, protos...) =
    instantiate_updater(VirtualTrackedSubFiber(fbr.lvl, fbr.pos, ctx.freshen(:null)), ctx, protos...)
function instantiate_updater(fbr::VirtualTrackedSubFiber{VirtualSparseListLevel}, ctx, ::Union{typeof(defaultupdate), typeof(extrude)}, protos...)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    tag = lvl.ex
    Tp = lvl.Tp
    qos = ctx.freshen(tag, :_qos)
    qos_fill = lvl.qos_fill
    qos_stop = lvl.qos_stop
    dirty = ctx.freshen(tag, :dirty)

    Furlable(
        tight = lvl,
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $qos = $qos_fill + 1
            end,
            body = (ctx) -> Lookup(
                body = (ctx, idx) -> Thunk(
                    preamble = quote
                        if $qos > $qos_stop
                            $qos_stop = max($qos_stop << 1, 1)
                            Finch.resize_if_smaller!($(lvl.ex).idx, $qos_stop)
                            $(contain(ctx_2->assemble_level!(lvl.lvl, ctx_2, value(qos, lvl.Tp), value(qos_stop, lvl.Tp)), ctx))
                        end
                        $dirty = false
                    end,
                    body = (ctx) -> instantiate_updater(VirtualTrackedSubFiber(lvl.lvl, value(qos, lvl.Tp), dirty), ctx, protos...),
                    epilogue = quote
                        if $dirty
                            $(fbr.dirty) = true
                            $(lvl.ex).idx[$qos] = $(ctx(idx))
                            $qos += $(Tp(1))
                        end
                    end
                )
            ),
            epilogue = quote
                $(lvl.ex).ptr[$(ctx(pos)) + 1] = $qos - $qos_fill - 1
                $qos_fill = $qos - 1
            end
        )
    )
end
