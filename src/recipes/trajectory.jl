using LinearAlgebra

"""
    trajectory(x, y, [z]; kwargs...)
Plots a colored trajectory in 2D or 3D space.

## Key attribtues:

`color` = `:speed`: The coloring method for the trajectory.

Can be one of:
- `:speed`: Color by speed along the trajectory
- `:time`: Color by time index
- `<: AbstractVector`: Color by a custom vector of values
- `Union{<:Symbol, <:Colorant}`: Color by a fixed color

_Other attributes are shared with `Makie.Lines`._
"""
@recipe Trajectory (x,) begin
    """The coloring method for the trajectory"""
    color = :speed

    get_drop_attrs(Lines, [:color])...
end
Makie.conversion_trait(::Type{<:Trajectory}) = Makie.PointBased()

function Makie.plot!(plot::Trajectory{<:Tuple{<:AbstractVector{<:Point}}})
    map!(plot.attributes, [:color, :x], [:parsed_color]) do color, x
        if color === :speed
            if length(x) > 1
                parsed_color = map(norm, diff(x))
                prepend!(parsed_color, parsed_color[1])
            else
                parsed_color = fill(0.0f0, length(x))
            end
        elseif color === :time
            parsed_color = 1:length(x)
        else
            parsed_color = color
        end
        return (parsed_color,)
    end
    rasterize = pop_rasterize!(plot)
    lines!(plot, plot.attributes, plot.x; color = plot.parsed_color, rasterize)
end
Makie.convert_arguments(::Type{<:Trajectory}, x, y) = (Point2.(zip(x, y)),)
Makie.convert_arguments(::Type{<:Trajectory}, x, y, z) = (Point3.(zip(x, y, z)),)
