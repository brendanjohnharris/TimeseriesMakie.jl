"""
    trail(x, y; kwargs...)

Plot a fading trace of points in 2D or 3D space.

## Key attributes:
`npoints` = `automatic`: Fixes the length of the trail.
By default, this is equal to the
length of `x` and `y`.
If `npoints` is less than the length of `x` and `y`, the last `npoints` will be plotted.

`linecolor` = `@inherit linecolor`: Sets the color of the trail.
Should be a single color (e.g. "red", :red, (:red, 0.2), RGBA(0.1, 0.2, 0.3, 0.4)). This
value is overridden by `color`

`color` = `nothing`: Specifies the color values for the trail.

If `!isnothing(color)`, trail colors will be sampled from the `colormap` depending on the
value of `color`.
`color` can be:

- A collection of numbers representing values to be sampled from the colormap.
- A function of the index of a point in the trail (e.g. `Base.Fix2(^, 3)`).

`colormap` = `@inherit colormap`: Specifies the colormap to use for the trail when
`!isnothing(color)`.

`alpha` = `identity`: Controls the transparency profile of the trail. `alpha` can be:

- A single number (e.g. `0.5`).
- A function of the index of a point in the trail (e.g. `Base.Fix2(^, 3)`).
- A collection of numbers representing alpha values for each point in the trail.

To sidestep alpha normalization, explicitly pass a vector of alpha values.
"""
@recipe Trail (x,) begin
    linecolor = @inherit linecolor
    color = nothing
    colormap = @inherit colormap
    alpha = identity
    n_points = automatic

    get_drop_attrs(Lines, [:cycle, :alpha, :color, :linecolor, :colormap])...
end
Makie.conversion_trait(::Type{<:Trail}) = Makie.PointBased()

function Makie.plot!(plot::Trail{<:Tuple{<:AbstractVector{<:Point}}})

    # * Parse colors
    map!(plot.attributes, [:linecolor, :color, :colormap],
         [:parsed_color, :parsed_colormap]) do linecolor, color, colormap
        if isnothing(color) # Color and colormap are unused
            parsed_color = identity
            parsed_colormap = cgrad([maybecolor(linecolor)])
        else # Sample the colormap and ignore linencolor
            parsed_color = color
            parsed_colormap = cgrad(colormap)
        end

        return parsed_color, parsed_colormap # To be sampled after calculating points
    end

    # * Compute n_points
    map!(plot.attributes, [:x, :parsed_color, :alpha, :n_points],
         [:final_n_points]) do x, color, alpha, n_points
        isempty(x) && return 0

        if alpha isa Function
            nalpha = length(x)
        elseif eltype(alpha) <: Real
            nalpha = length(alpha)
        end
        if color isa Function
            ncolor = length(x)
        elseif eltype(color) <: Real
            ncolor = length(color)
        end

        final_n_points = min(length(x), nalpha, ncolor)

        if n_points != automatic
            final_n_points = min(final_n_points, n_points)
        end

        return (final_n_points,)
    end

    # * Sample colormap
    map!(plot.attributes, [:parsed_color, :parsed_colormap, :final_n_points],
         [:processed_color]) do color, colormap, n_points
        if color isa Function
            color = color.(1:n_points)
        else
            color = collect(color[(end - n_points + 1):end])
        end
        processed_color = colormap[minmax(color)]
        return (processed_color,)
    end

    # * Sample alphamap
    map!(plot.attributes, [:alpha, :final_n_points],
         [:processed_alpha]) do alpha, n_points
        if alpha isa Function
            alpha_vals = alpha.(1:n_points) |> minmax
        else
            alpha_vals = collect(alpha[(end - n_points + 1):end])
        end
        return (alpha_vals,)
    end

    # * Blend alpha
    map!(plot.attributes, [:processed_color, :processed_alpha],
         [:final_color]) do color, alpha
        final_color = map(color, alpha) do c, a
            Makie.coloralpha(c, c.alpha * a)
        end
        return (final_color,)
    end

    # * Trim points
    map!(plot.attributes, [:x, :final_n_points],
         [:final_x]) do x, n_points
        if isempty(x)
            final_x = x
        elseif n_points == 1
            offset = min(n_points, length(x))
            final_x = @view x[(end - offset + 1):end]
        else
            final_x = @view x[(end - n_points + 1):end]
        end
        return (final_x,)
    end
    lines!(plot, plot.attributes, plot.final_x; color = plot.final_color,
           colormap = :viridis, alpha = 1.0)
end
Makie.convert_arguments(::Type{<:Trail}, x, y) = (Point2.(zip(x, y)),)
Makie.convert_arguments(::Type{<:Trail}, x, y, z) = (Point3.(zip(x, y, z)),)
