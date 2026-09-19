"""
    kinetic(x, y; kwargs...)

Plots a line with a varying width.

## Key attribtues:

`linewidth` = `:curv`:

Sets the algorithm for determining the line width.

- `:curv` - Width is determined by the velocity

- `:x` - Width is determined by the x-coordinate

- `:y` - Width is determined by the y-coordinate

- `<: Number` - Width is set to a constant value

`linewidthscale` = `1`: Scale factor for the line width.

_Other attributes are shared with `Makie.Lines`._
"""
@recipe Kinetic (x,) begin
    cycle = :color
    color = @inherit linecolor
    linewidth = :curv
    linewidthscale = 1
    linecap = :round

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
# number of segments `interleave` emits; a lone point still gets one (degenerate) segment
nsegments(n) = max(1, n - 1)

# map a profile onto the 1-11 width range. A constant profile lands mid-range (see `minmax`),
# so a straight line draws at a uniform width instead of vanishing behind `NaN`.
towidths(l) = minmax(l) .* 10 .+ 1

function minter(x)
    length(x) < 2 && return towidths(ones(1))
    l = map(eachindex(x)) do i
        i == 1 ? x[1] : (x[i - 1] + x[i]) / 2
    end
    return towidths(l)[2:end]
end

function difter(x)
    n = length(x)
    n < 3 && return towidths(ones(nsegments(n))) # curvature needs three points
    l = map(eachindex(x)) do i
        j = clamp(i, 2, n - 1) # reuse the end curvatures for the endpoints
        x[j + 1] - 2 * x[j] + x[j - 1]
    end
    return towidths(exp.(-abs.(l) .^ 2))[2:end]
end

function Makie.plot!(plot::Kinetic{<:Tuple{<:Vector{<:Point{2, T}}}}) where {T <: Real}
    map!(plot.attributes, [:linewidth, :x, :linewidthscale],
         :linewidths) do l, xy, lscale
        x = map(first, xy)
        y = map(last, xy)
        if l isa Number
            l = fill(l, nsegments(length(x)))
        elseif l === :x
            l = minter(x)
        elseif l === :y
            l = minter(y)
        elseif l === :curv
            l = difter(y)
        end
        [x for x in l for _ in 1:2] .* lscale
    end

    map!(plot.attributes, [:x], :final_x) do xy
        interleave(xy)
    end
    rasterize = pop_rasterize!(plot)
    linesegments!(plot, plot.attributes, plot.final_x;
                  linewidth = plot.attributes[:linewidths], rasterize)
end
