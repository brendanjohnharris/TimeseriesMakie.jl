using LinearAlgebra

"""
    kinetic(x, y; kwargs...)

Plots a line with a varying width.

## Key attributes

`linewidth` = `:curv`: the width profile along the line, one value per point.

- `:curv` - as wide as the curve has room for. Crowded stretches draw narrow, so a fast
  passage stays legible beside a slow one; open stretches draw at the full width
- `:x`, `:y` - from that coordinate, mapped onto `widthrange`
- `<: Number` - constant

`widthrange` = `(1, 11)`: the narrowest and widest the stroke may draw, in pixels.

`linewidthscale` = `1`: Scale factor for the line width.

## Crowding

`:curv` measures, at each point, the radius of the largest disc tangent to the curve holding no
other part of it: for a circle of radius `R` that is `R`, and for two strands `d` apart it is
`d/2`. A tight turn and a near miss are one quantity, of how much room there is, and the stroke
has only to fit inside it. Because the room is measured in pixels, the widths respond to zoom:
magnify a dense passage and the stroke fattens as its structure becomes resolvable.

`crowding` = `0.5`: the fraction of that room the stroke fills. `1` lets two neighbouring
strands just touch, leaving no visible gap.

`taper` = `0.02`: the largest relative change in width per pixel travelled along the curve. It
also sets how far a narrow spot spreads into its surroundings, and the two cannot be separated:
lower it to flatten the width across an oscillation, raise it to keep isolated thin loops at
their full width.

`geometry` = `:auto`: how the stroke is drawn. Read once at construction; changing it later has
no effect.

- `:auto` - `:lines` on GLMakie and WGLMakie, `:mesh` on every other backend
- `:mesh` - a triangle stroke built in pixel space. Continuous taper, uniform transparency and a
  width isotropic in pixels on any axis, on every backend; caps and joins are always round
- `:lines` - a single `lines` carrying one width per point. Renders as `:mesh` does on GLMakie
  and WGLMakie, which stroke a varying width natively; CairoMakie cannot, and errors
- `:segments` - a `linesegments` with one width per segment, hiding the joints behind `linecap`.
  Works everywhere, but the width steps between segments and translucent colours bead at the
  joints

_Other attributes are shared with `Makie.Lines`._
"""
@recipe Kinetic (x,) begin
    cycle = :color
    color = @inherit linecolor
    linewidth = :curv
    linewidthscale = 1
    linecap = :round
    "The narrowest and widest the stroke may draw, in pixels."
    widthrange = (1, 11)
    """Fraction of the available room a `:curv` stroke fills. `1` lets two neighbouring strands
    just touch, leaving no visible gap between them."""
    crowding = 0.5
    "Largest relative change in a `:curv` width per pixel travelled along the curve."
    taper = 0.02
    """How the stroke is drawn; see the docstring. Read once at construction."""
    geometry = :auto

    get_drop_attrs(Lines, [:cycle, :color, :linewidth, :linecap])...
end
Makie.conversion_trait(::Type{<:Kinetic}) = Makie.PointBased()

function interleave(x)
    # Create segments as pairs of consecutive points
    segments = Vector{eltype(x)}()
    if length(x) == 1
        push!(segments, x[1])
        push!(segments, x[1])
    else
        for i in 1:(length(x) - 1)
            push!(segments, x[i])
            push!(segments, x[i + 1])
        end
    end
    return segments
end

# map a profile onto `widthrange`. A constant profile lands mid-range (see `minmax`), so a
# straight line draws at a uniform width instead of vanishing behind `NaN`.
towidths(l, (lo, hi)) = minmax(l) .* (hi - lo) .+ lo

"""
    ballradius(X, Y, cap)

Radius of the largest disc tangent to the curve at each point that contains no other part of it,
in the pixel coordinates `X`, `Y`, saturating at `cap`.

For a circle of radius `R` this returns `R`; for two strands `d` apart it returns `d/2`. A tight
turn and a near miss are therefore one measurement, of how much room the curve has, and the
stroke has only to fit inside it. The disc tangent at `Pᵢ` on the normal side, centred
`Pᵢ + r nᵢ`, contains `Pⱼ` exactly when `|d|² < 2r (d·nᵢ)` with `d = Pⱼ - Pᵢ`.

No arc-length exclusion is needed: an arc-neighbour of a smooth curve gives `|d|²/(2 d·nᵢ) →`
the osculating radius by itself, so curvature is the limit of the same formula rather than a
separate case. Only points within `2cap` can bind the result, so they are bucketed into cells of
that size and only the neighbouring nine are scanned, giving expected `O(n)`.
"""
function ballradius(X, Y, cap)
    n = length(X)
    out = fill(float(cap), n)
    n < 3 && return out
    ok = isfinite.(X) .& isfinite.(Y)
    c(v) = [v[clamp(i, 2, n - 1) + 1] - v[clamp(i, 2, n - 1) - 1] for i in 1:n] ./ 2
    tx, ty = c(X), c(Y)
    L = max.(hypot.(tx, ty), eps())
    nx, ny = -ty ./ L, tx ./ L                       # unit normal
    cell = 2cap
    key(i) = (floor(Int, X[i] / cell), floor(Int, Y[i] / cell))
    buckets = Dict{Tuple{Int, Int}, Vector{Int}}()
    for i in 1:n
        ok[i] && push!(get!(buckets, key(i), Int[]), i)
    end
    for i in 1:n
        (ok[i] && isfinite(nx[i])) || continue
        cx, cy = key(i)
        rp = rm = float(cap)
        for ox in -1:1, oy in -1:1
            for j in get(buckets, (cx + ox, cy + oy), Int[])
                dx, dy = X[j] - X[i], Y[j] - Y[i]
                s2 = dx * dx + dy * dy
                s2 < 1.0f-12 && continue
                proj = dx * nx[i] + dy * ny[i]
                if proj > 1.0f-9
                    rp = min(rp, s2 / (2proj))
                elseif proj < -1.0f-9
                    rm = min(rm, s2 / (-2proj))
                end
            end
        end
        out[i] = min(rp, rm)
    end
    return out
end

# Soft minimum of `b` over a disc of radius `ρ`. Space is the right domain for this: a disc
# around one strand of a dense oscillation holds its neighbours, while a disc around the middle
# of a long thin loop holds only the loop's own two sides, though along the arc the two look
# identical. `p`-norm rather than a true minimum, which would step.
function spatialmin(X, Y, b, ρ; p = 4)
    n = length(X)
    out = collect(float.(b))
    ok = isfinite.(X) .& isfinite.(Y)
    buckets = Dict{Tuple{Int, Int}, Vector{Int}}()
    key(i) = (floor(Int, X[i] / ρ), floor(Int, Y[i] / ρ))
    for i in 1:n
        ok[i] && push!(get!(buckets, key(i), Int[]), i)
    end
    for i in 1:n
        ok[i] || continue
        cx, cy = key(i)
        acc = 0.0
        cnt = 0
        for ox in -1:1, oy in -1:1
            for j in get(buckets, (cx + ox, cy + oy), Int[])
                (X[i] - X[j])^2 + (Y[i] - Y[j])^2 > ρ^2 && continue
                acc += b[j]^-p
                cnt += 1
            end
        end
        cnt > 0 && (out[i] = (acc / cnt)^(-1 / p))
    end
    return out
end

# Lower envelope of cones, w(s) = min over t of b(t) + L|s - t|, in two passes. Everywhere at or
# below `b`, so the stroke always fits, and never steeper than `L`, so no transition is sharp.
# Averaging is the wrong tool here: a rolling mean can push the width above `b`, it is a box
# filter, and it runs over sample index rather than arc length.
function slopelimit(b, s, L)
    n = length(b)
    w = collect(float.(b))
    for i in 2:n
        w[i] = min(w[i], w[i - 1] + L * (s[i] - s[i - 1]))
    end
    for i in (n - 1):-1:1
        w[i] = min(w[i], w[i + 1] + L * (s[i + 1] - s[i]))
    end
    return w
end

# Gaussian in arc length, rounding the corners where cones meet. `σ` is in pixels, so uneven
# sampling does not change the amount of smoothing.
function gsmooth(v, s, σ)
    n = length(v)
    out = similar(float.(v))
    lo = 1
    for i in 1:n
        while s[i] - s[lo] > 3σ
            lo += 1
        end
        hi = i
        while hi < n && s[hi + 1] - s[i] < 3σ
            hi += 1
        end
        num = den = 0.0
        for j in lo:hi
            k = exp(-((s[j] - s[i]) / σ)^2 / 2)
            num += k * v[j]
            den += k
        end
        out[i] = den > 0 ? num / den : v[i]
    end
    return out
end

"""
    crowdwidths(P, widthrange, crowding, taper)

One width per point of the pixel-space path `P`, so that the stroke fits the room the curve has.

`ballradius` gives that room; `crowding` is the fraction of it the stroke fills (1 means two
neighbouring strands just touch, leaving no visible gap). The bound is then eroded over a disc,
and finally limited to a relative rate of change of `taper` per pixel travelled along the curve:
a *relative* limit, because a change from 1 to 2 px reads as strongly as one from 5 to 10 px.
"""
function crowdwidths(P::AbstractVector{<:Point2}, (wmin, wmax), crowding, taper)
    n = length(P)
    n < 3 && return fill(float(wmax), n)
    X, Y = first.(P), last.(P)
    step = hypot.(diff(X), diff(Y))
    s = vcat(0.0, cumsum(map(d -> isfinite(d) ? d : 0.0, step)))   # a NaN gap must not poison it
    b = clamp.(crowding .* 2 .* ballradius(X, Y, wmax), wmin, wmax)
    b = spatialmin(X, Y, b, 2 * wmax)
    w = exp.(slopelimit(log.(b), s, taper))
    return max.(gsmooth(w, s, 4.0), wmin)
end

"""
    widthprofile(mode, xy, P, widthrange, crowding, taper)

One width per point, from `mode`: a `Number` for a constant width, `:x` or `:y` for that
coordinate mapped onto `widthrange`, or `:curv` for the room the curve has at each point.

`xy` are the data-space points and `P` the same points in pixels; only `:curv` needs `P`.
"""
function widthprofile(mode, xy, P, widthrange, crowding, taper)
    mode isa Number && return fill(float(mode), length(xy))
    mode === :x && return towidths(first.(xy), widthrange)
    mode === :y && return towidths(last.(xy), widthrange)
    mode === :curv ||
        throw(ArgumentError("linewidth must be :curv, :x, :y or a Number, got $mode"))
    return crowdwidths(P, widthrange, crowding, taper)
end

# one width per `interleave`d endpoint: a segment takes the mean of its two point widths.
# A lone point still gets one (degenerate) segment.
function segmentwidths(w)
    length(w) == 1 && return [w[1], w[1]]
    return repeat((w[1:(end - 1)] .+ w[2:end]) ./ 2, inner = 2)
end

# GLMakie and WGLMakie stroke a varying linewidth natively; no other backend does, so everything
# else falls to the mesh. A recipe cannot ask its parent scene which backend will draw it.
function autogeometry()
    backend = Makie.current_backend()
    return backend isa Module && nameof(backend) in (:GLMakie, :WGLMakie) ? :lines : :mesh
end

"""
    strokemesh(P, w) -> (vertices, faces, source)

Triangle mesh for a variable-width line through the pixel-space points `P`, `w[i]` pixels wide
at `P[i]`. Each segment is a quad tapering linearly between its end widths; a vertex gets a fan
only where the path turns enough to open a visible gap on the outside, and the ends get round
caps. Triangles overdraw rather than being subtracted by a fill rule, so a turn tighter than the
half-width stays solid. `NaN` points break the stroke without a cap. `source[k]` is the index in
`P` that vertex `k` belongs to, for expanding per-point colours.
"""
function strokemesh(P::AbstractVector{<:Point2}, w::AbstractVector)
    Face = Makie.GeometryBasics.GLTriangleFace
    n = length(P)
    V = Point2f[]
    S = Int[]
    F = Face[]
    function tri!(a, b, c, i, j, k)
        m = length(V)
        push!(V, a, b, c)
        push!(S, i, j, k)
        push!(F, Face(m + 1, m + 2, m + 3))
    end
    rot(v, θ) = Point2f(v[1] * cos(θ) - v[2] * sin(θ), v[1] * sin(θ) + v[2] * cos(θ))
    function dir(a, b) # unit direction; `nothing` for a degenerate or NaN segment
        d = b - a
        nd = norm(d)
        return nd > 1.0f-9 ? d ./ nd : nothing
    end
    function fan!(i, v0, sweep) # wedge of `sweep` rad about P[i], within 0.2 px of the true arc
        step = 2 * acos(clamp(1 - 0.2 / norm(v0), -1, 1))
        k = max(1, ceil(Int, abs(sweep) / step))
        for j in 1:k
            tri!(P[i], P[i] + rot(v0, sweep * (j - 1) / k), P[i] + rot(v0, sweep * j / k),
                 i, i, i)
        end
    end
    n == 0 && return V, F, S
    if n == 1 # a lone point draws as a dot
        fan!(1, Point2f(0, w[1] / 2), Float32(2π))
        return V, F, S
    end
    for i in 1:(n - 1) # segment quads
        u = dir(P[i], P[i + 1])
        isnothing(u) && continue
        m = Point2f(-u[2], u[1])
        a1, b1 = P[i] + m * (w[i] / 2), P[i] - m * (w[i] / 2)
        a2, b2 = P[i + 1] + m * (w[i + 1] / 2), P[i + 1] - m * (w[i + 1] / 2)
        tri!(a1, b1, a2, i, i, i + 1)
        tri!(b1, b2, a2, i, i + 1, i + 1)
    end
    for i in 2:(n - 1) # joins, only where the outer gap would show
        d1 = dir(P[i - 1], P[i])
        d2 = dir(P[i], P[i + 1])
        (isnothing(d1) || isnothing(d2)) && continue
        ang = atan(d1[1] * d2[2] - d1[2] * d2[1], clamp(dot(d1, d2), -1, 1)) # signed turn
        abs(ang) * w[i] / 2 < 0.1 && continue # gap narrower than 0.1 px
        m1 = Point2f(-d1[2], d1[1]) * (w[i] / 2)
        fan!(i, ang > 0 ? -m1 : m1, ang) # outer edge of segment i-1 round to segment i
    end
    for (i, u) in ((1, dir(P[1], P[2])), (n, dir(P[n], P[n - 1]))) # round caps
        isnothing(u) && continue
        fan!(i, Point2f(-u[2], u[1]) * (w[i] / 2), Float32(π))
    end
    return V, F, S
end

function Makie.plot!(plot::Kinetic{<:Tuple{<:Vector{<:Point{2, T}}}}) where {T <: Real}
    # `:curv` measures how much room the curve has in pixels, so it needs the projected points,
    # and it re-fires on zoom: magnify a dense passage and the stroke fattens as it becomes
    # resolvable. Registered for every geometry so the widths mean the same thing in each.
    register_projected_positions!(plot, Point2f; input_name = :x,
                                  output_name = :pixel_points, output_space = :pixel)
    map!(plot.attributes,
         [:linewidth, :x, :pixel_points, :widthrange, :crowding, :taper, :linewidthscale],
         :pointwidths) do mode, xy, P, wr, crowding, taper, lscale
        widthprofile(mode, xy, P, wr, crowding, taper) .* lscale
    end
    rasterize = pop_rasterize!(plot)
    geometry = plot.geometry[] # read once, like `doband` in spectrumplot
    geometry === :auto && (geometry = autogeometry())

    if geometry === :segments
        map!(segmentwidths, plot.attributes, [:pointwidths], :linewidths)
        map!(interleave, plot.attributes, [:x], :final_x)
        linesegments!(plot, plot.attributes, plot.final_x; linewidth = plot.linewidths,
                      rasterize)
    elseif geometry === :lines
        lines!(plot, plot.attributes, plot.x; linewidth = plot.pointwidths, rasterize)
    elseif geometry === :mesh
        map!(plot.attributes, [:pixel_points, :pointwidths, :color],
             [:strokeverts, :strokefaces, :strokecolor]) do P, w, c
            V, F, S = strokemesh(P, w)
            return (V, F, c isa AbstractVector && length(c) == length(P) ? c[S] : c)
        end
        # ! CairoMakie paints a mesh 16384 patches at a time, so a translucent stroke of more
        # than ~8000 points can double-blend at one joint per batch
        mesh!(plot, plot.attributes, plot.strokeverts, plot.strokefaces;
              color = plot.strokecolor, space = :pixel, shading = NoShading, rasterize)
    else
        throw(ArgumentError("geometry must be :auto, :mesh, :lines or :segments, got $geometry"))
    end
    return plot
end

# widths are pixels and the mesh lives in pixel space, so only the points set the limits
Makie.data_limits(plot::Kinetic) = Makie.Rect3d(plot.x[])
function Makie.boundingbox(plot::Kinetic, space::Symbol)
    return Makie.apply_transform_and_model(plot, Makie.data_limits(plot))
end
