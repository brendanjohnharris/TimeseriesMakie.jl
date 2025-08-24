
"""
    shadows(x, y, z; kwargs...)
Plots shadows of a 3D trajectory onto the enclosing axis panes.

## Key attributes:

`mode` = `:projection`: The shadowing mode

`swapshadows` = `automatic`: Whether to swap the axes for each shadow.

Can be:

- `true` or `false`: Swap the axes for all shadows from their default values

- `NTuple{3, Bool}`: Swap the default axes for each shadow individually (x, y, z)

- `automatic`: Defaults to `(true, true, false)`

`limits` = `automatic`: The targeted axis limits. To ensure the shadows align with the axes,
it is best to provide the `Axis` limits here. If `automatic`, the limits are inferred
from the data.

_Other attributes are shared with `Makie.Lines`._
"""
@recipe Shadows (x,) begin
    """The shadowing mode"""
    mode = :projection

    """Whether to swap the axes for each shadow"""
    swapshadows = automatic

    """The targeted axis limits"""
    limits = automatic

    get_drop_attrs(Lines, [])...
end
Makie.conversion_trait(::Type{<:Shadows}) = Makie.PointBased()

function Makie.plot!(plot::Shadows{<:Tuple{<:AbstractVector{<:Point3}}})
    map!(plot.attributes, [:x, :mode, :swapshadows, :limits],
         [:xs, :ys, :zs]) do x, mode, swapshadows, limits
        _x = map(Base.Fix2(getindex, 1), x)
        _y = map(Base.Fix2(getindex, 2), x)
        _z = map(Base.Fix2(getindex, 3), x)

        if limits === automatic
            limits = (extrema(_x), extrema(_y), extrema(_z))
        end

        N = length(x)
        if swapshadows === false
            swapshadows = (false, false, false)
        end
        if swapshadows === automatic
            swapshadows = (true, true, false)
        end
        planes = map(limits, swapshadows) do l, s
            p = s ? last(l) .+ eps() : first(l) .- eps()
            return fill(p, N)
        end
        if mode === :projection
            xs = map(Point3f, zip(planes[1], _y, _z))
            ys = map(Point3f, zip(_x, planes[2], _z))
            zs = map(Point3f, zip(_x, _y, planes[3]))
        else
            throw(ArgumentError("Unsupported shadow mode: $mode"))
        end
        return (xs, ys, zs)
    end

    lines!(plot, plot.attributes, plot.xs)
    lines!(plot, plot.attributes, plot.ys)
    lines!(plot, plot.attributes, plot.zs)
end
Makie.convert_arguments(::Type{<:Shadows}, x, y, z) = (Point3f.(zip(x, y, z)),)
