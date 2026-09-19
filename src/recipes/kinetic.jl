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
function minter(x)
    l = map(eachindex(x)) do i
        if i == 1
            x[1]
        else
            mean(x[(i - 1):i])
        end
    end
    l = l .- minimum(l)
    l = l ./ maximum(l)
    l .*= 10
    l .+= 1
    return l[2:end]
end

function difter(x)
    l = map(eachindex(x)) do i
        if i < 2
            x[3] - 2 * x[2] + x[1]
        elseif i > length(x) - 1
            x[end - 2] - 2 * x[end - 1] + x[end]
        else
            x[i + 1] - 2 * x[i] + x[i - 1]
        end
    end
    l = exp.(-abs.(l) .^ 2)
    l = l .- minimum(l)
    l = l ./ maximum(l)
    l .*= 10
    l .+= 1
    return l[2:end]
end

function Makie.plot!(plot::Kinetic{<:Tuple{<:Vector{<:Point{2, T}}}}) where {T <: Real}
    map!(plot.attributes, [:linewidth, :x, :linewidthscale],
         :linewidths) do l, xy, lscale
        x = map(first, xy)
        y = map(last, xy)
        if l isa Number
            l = fill(l, length(x) - 1)
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
