"""
    traces(x, y, Z; kwargs...)
Plot the columns of `Z` over the domain `x`, colored by `y`.

## Key attributes:

- `linecolor` = `automatic`: Sets the color of the traces.

- `spacing` = `0`: The spacing between traces.

Can be a number in data space, or one of the following modes:
    - `:even`: Even spacing equal to the greatest difference between traces.
    - `:close`: Successive traces are spaced by the smallest difference between them.

- `offset` = `1`: The offset factor (offset * spacing)

_Other attributes are shared with `Makie.Lines`._
"""
@recipe Traces (x, y, Z) begin
    offset = 1
    spacing = 0
    linecolor = automatic

    get_drop_attrs(Lines, [:color])...
end

function Makie.plot!(plot::Traces{<:Tuple{<:AbstractVector, <:AbstractVector,
                                          <:AbstractMatrix}})
    map!(plot.attributes, [:linecolor, :x, :y, :Z], [:final_color]) do color, x, y, Z
        if color === automatic
            n = min(length(x), size(Z, 1)) # `final_x` zips x with each column, so it truncates too
            cs = repeat(y', n)
            cs = vcat(cs, fill(NaN, 1, size(cs, 2)))
            return (Iterators.flatten(cs) |> collect,)
        else
            return (color,)
        end
    end

    map!(plot.attributes, [:Z, :spacing, :offset], [:stacked_Z]) do Z, spacing, offset
        c = zeros(size(Z, 2)) .* unit(eltype(Z))
        if spacing isa Symbol
            spacing in (:even, :close) ||
                throw(ArgumentError("`spacing` must be a number, `:even` or `:close`; got `:$spacing`"))
            if spacing === :even && size(Z, 2) > 1
                # * Space is the difference between the minimum of 2 and the maximum of 1
                space = maximum([minimum(Z[:, i]) - maximum(Z[:, i - 1])
                                 for i in axes(Z, 2)[2:end]])
            end
            for i in axes(Z, 2)[2:end]
                if spacing === :close
                    space = maximum(Z[:, i - 1] .- Z[:, i])
                end
                c[i] = c[i - 1] + space * offset
            end
        else
            if unit(spacing) === NoUnits
                spacing = spacing * unit(eltype(Z))
            end
            c .= (0:(length(c) - 1)) .* (spacing * offset) # cumulative, as for the symbolic modes
        end
        stacked_Z = Z .+ c'
        return (stacked_Z,)
    end

    map!(plot.attributes, [:x, :stacked_Z], [:final_x]) do x, Z
        xys = map(eachcol(Z)) do _z
            xy = Point2.(zip(x, _z))
            push!(xy, Point2([NaN, NaN] .* unit(eltype(Z))))
            return xy
        end
        return (vcat(xys...),)
    end

    rasterize = pop_rasterize!(plot)
    lines!(plot, plot.attributes, plot.final_x; color = plot.final_color, rasterize)
end
