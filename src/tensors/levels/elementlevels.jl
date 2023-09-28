"""
    ElementLevel{D, [Tv=typeof(D), Tp=Int, Val]}()

A subfiber of an element level is a scalar of type `Tv`, initialized to `D`. `D`
may optionally be given as the first argument.

The data is stored in a vector
of type `Val` with `eltype(Val) = Tv`. The type `Ti` is the index type used to
access Val.

```jldoctest
julia> Fiber!(Dense(Element(0.0)), [1, 2, 3])
Dense [1:3]
├─[1]: 1.0
├─[2]: 2.0
├─[3]: 3.0
```
"""
struct ElementLevel{D, Tv, Tp, Val}
    val::Val
end
const Element = ElementLevel

function ElementLevel(d, args...)
    isbits(d) || throw(ArgumentError("Finch currently only supports isbits defaults"))
    ElementLevel{d}(args...)
end
ElementLevel{D}() where {D} = ElementLevel{D, typeof(D)}()
ElementLevel{D}(val::Val) where {D, Val} = ElementLevel{D, eltype(Val)}(val)
ElementLevel{D, Tv}(args...) where {D, Tv} = ElementLevel{D, Tv, Int}(args...)
ElementLevel{D, Tv, Tp}() where {D, Tv, Tp} = ElementLevel{D, Tv, Tp}(Tv[])

ElementLevel{D, Tv, Tp}(val::Val) where {D, Tv, Tp, Val} = ElementLevel{D, Tv, Tp, Val}(val)

Base.summary(::Element{D}) where {D} = "Element($(D))"

similar_level(::ElementLevel{D, Tv, Tp}) where {D, Tv, Tp} = ElementLevel{D, Tv, Tp}()

postype(::Type{<:ElementLevel{D, Tv, Tp}}) where {D, Tv, Tp} = Tp

function moveto(lvl::ElementLevel{D, Tv, Tp}, device) where {D, Tv, Tp}
    return ElementLevel{D, Tv, Tp}(moveto(lvl.val, device))
end

pattern!(lvl::ElementLevel{D, Tv, Tp}) where  {D, Tv, Tp} =
    Pattern{Tp}()
redefault!(lvl::ElementLevel{D, Tv, Tp}, init) where {D, Tv, Tp} = 
    ElementLevel{init, Tv, Tp}(lvl.val)


function Base.show(io::IO, lvl::ElementLevel{D, Tv, Tp, Val}) where {D, Tv, Tp, Val}
    print(io, "Element{")
    show(io, D)
    print(io, ", $Tv, $Tp}(")
    if get(io, :compact, false)
        print(io, "…")
    else
        show(io, lvl.val)
    end
    print(io, ")")
end 

function display_fiber(io::IO, mime::MIME"text/plain", fbr::SubFiber{<:ElementLevel}, depth)
    p = fbr.pos
    show(io, mime, fbr.lvl.val[p])
end

@inline level_ndims(::Type{<:ElementLevel}) = 0
@inline level_size(::ElementLevel) = ()
@inline level_axes(::ElementLevel) = ()
@inline level_eltype(::Type{<:ElementLevel{D, Tv}}) where {D, Tv} = Tv
@inline level_default(::Type{<:ElementLevel{D}}) where {D} = D
data_rep_level(::Type{<:ElementLevel{D, Tv}}) where {D, Tv} = ElementData(D, Tv)

(fbr::Fiber{<:ElementLevel})() = SubFiber(fbr.lvl, 1)()
function (fbr::SubFiber{<:ElementLevel})()
    q = fbr.pos
    return fbr.lvl.val[q]
end

countstored_level(lvl::ElementLevel, pos) = pos

mutable struct VirtualElementLevel <: AbstractVirtualLevel
    ex
    D
    Tv
    Tp
    val
end

is_level_injective(::VirtualElementLevel, ctx) = []
is_level_atomic(lvl::VirtualElementLevel, ctx) = false

lower(lvl::VirtualElementLevel, ctx::AbstractCompiler, ::DefaultStyle) = lvl.ex

function virtualize(ex, ::Type{ElementLevel{D, Tv, Tp, Val}}, ctx, tag=:lvl) where {D, Tv, Tp, Val}
    sym = freshen(ctx, tag)
    val = virtualize(:($ex.val), Val, ctx, :val)
    push!(ctx.preamble, quote
        $sym = $ex
    end)
    VirtualElementLevel(sym, D, Tv, Tp, val)
end

Base.summary(lvl::VirtualElementLevel) = "Element($(lvl.D))"

virtual_level_resize!(lvl::VirtualElementLevel, ctx) = lvl
virtual_level_size(::VirtualElementLevel, ctx) = ()
virtual_level_eltype(lvl::VirtualElementLevel) = lvl.Tv
virtual_level_default(lvl::VirtualElementLevel) = lvl.D

postype(lvl::VirtualElementLevel) = lvl.Tp

function declare_level!(lvl::VirtualElementLevel, ctx, pos, init)
    init == literal(lvl.D) || throw(FinchProtocolError("Cannot initialize Element Levels to non-default values(have $init expected $(lvl.D))"))
    lvl
end

freeze_level!(lvl::VirtualElementLevel, ctx, pos) = lvl

thaw_level!(lvl::VirtualElementLevel, ctx::AbstractCompiler, pos) = lvl

function trim_level!(lvl::VirtualElementLevel, ctx::AbstractCompiler, pos)
    push!(ctx.code.preamble, quote
        resize!($(ctx(lvl.val)), $(ctx(pos)))
    end)
    return lvl
end

function assemble_level!(lvl::VirtualElementLevel, ctx, pos_start, pos_stop)
    pos_start = cache!(ctx, :pos_start, simplify(pos_start, ctx))
    pos_stop = cache!(ctx, :pos_stop, simplify(pos_stop, ctx))
    quote
        Finch.resize_if_smaller!($(ctx(lvl.val)), $(ctx(pos_stop)))
        Finch.fill_range!($(ctx(lvl.val)), $(lvl.D), $(ctx(pos_start)), $(ctx(pos_stop)))
    end
end

supports_reassembly(::VirtualElementLevel) = true
function reassemble_level!(lvl::VirtualElementLevel, ctx, pos_start, pos_stop)
    pos_start = cache!(ctx, :pos_start, simplify(pos_start, ctx))
    pos_stop = cache!(ctx, :pos_stop, simplify(pos_stop, ctx))
    push!(ctx.code.preamble, quote
        Finch.fill_range!($(ctx(lvl.val)), $(lvl.D), $(ctx(pos_start)), $(ctx(pos_stop)))
    end)
    lvl
end

function virtual_moveto_level(lvl::VirtualElementLevel, ctx::AbstractCompiler, arch)
    lvl.val = virtual_moveto(lvl.val, ctx, arch)
    return lvl
end

function instantiate_reader(fbr::VirtualSubFiber{VirtualElementLevel}, ctx, protos)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    val = freshen(ctx.code, lvl.ex, :_val)
    return Thunk(
        preamble = quote
            $val = $(ctx(lvl.val))[$(ctx(pos))]
        end,
        body = (ctx) -> VirtualScalar(nothing, lvl.Tv, lvl.D, gensym(), val)
    )
end

function instantiate_updater(fbr::VirtualSubFiber{VirtualElementLevel}, ctx, protos)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    VirtualScalar(nothing, lvl.Tv, lvl.D, gensym(), :($(ctx(lvl.val))[$(ctx(pos))]))
end

function instantiate_updater(fbr::VirtualTrackedSubFiber{VirtualElementLevel}, ctx, protos)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    VirtualDirtyScalar(nothing, lvl.Tv, lvl.D, gensym(), :($(ctx(lvl.val))[$(ctx(pos))]), fbr.dirty)
end