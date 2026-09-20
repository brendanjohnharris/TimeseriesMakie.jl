module TimeseriesMakie

using Makie
using Random
using Makie.Unitful

# ? Format recipe docstrings
using Makie.DocStringExtensions
import Makie: DocThemer, ATTRIBUTES, DocInstances, INSTANCES, Linestyle

import Makie: mixin_generic_plot_attributes, mixin_colormap_attributes,
              documented_attributes, attribute_names, DocumentedAttributes, automatic

function get_attrs(P::Type{<:Plot})
    # Makie.attribute_default_expressions(P)
    Makie.documented_attributes(P)
end
function drop_attrs(attrs::DocumentedAttributes, keys)
    attrs = deepcopy(attrs)
    map(collect(keys)) do key
        if haskey(attrs.d, key)
            delete!(attrs.d, key)
        end
    end
    return attrs
end
function get_drop_attrs(P::Type{<:Plot}, keys)
    attrs = get_attrs(P)
    return drop_attrs(attrs, keys)
end

MColor = Union{<:AbstractString, <:Symbol}
MakieColor = Union{<:MColor, <:Tuple{<:MColor, <:Number}}
maybecolor(x::MakieColor) = Makie.to_color(x)
maybecolor(x) = x

"""
    minmax(x)

Normalise `x` onto `[0, 1]`. A constant `x` has no ordering to normalise, so it maps to the
middle of the range rather than to `0/0`; callers use the result to index colormaps and
alpha profiles, where a `NaN` silently renders nothing.
"""
function minmax(x)
    isempty(x) && return float.(x)
    lo, hi = extrema(x)
    lo == hi && return fill(0.5, size(x))
    return (x .- lo) ./ (hi - lo)
end
minmax(x::Number) = x

"""
    pop_rasterize!(plot)

Remove `rasterize` from a recipe's `plot.kw` and return it, for forwarding to the child plot.

`rasterize` reaches a plot through `plot.kw` and is registered on it only after `plot!`
returns. Left on a recipe, CairoMakie treats that recipe as atomic and hands it to an
unsupported `draw_atomic`: a warning, and no rasterisation. Only worth doing when the child is
a primitive; giving it to another recipe just moves the problem down a level.
"""
pop_rasterize!(plot) = Makie.to_value(pop!(plot.kw, :rasterize, false))
include("Recipes.jl")

# * Extensions
"""
    spectrumplot(x; kwargs...)
    spectrumplot(f, s; kwargs...)

Plot a power spectrum, optionally marking and labelling its prominent peaks. Requires the
`TimeseriesTools` extension (`using TimeseriesTools`).

`x` may be a `UnivariateSpectrum`, a `MultivariateSpectrum` (reduced to a line and a spread
band), an `AbstractTimeseries` (its `spectrum` is taken first), or a vector of `Point2`.
Given two arguments, `f` holds the frequencies and `s` the spectral density.

## Key attributes:

- `peaks` = `false`: mark prominent peaks. `true` marks every one found, an `Int` the `n` most
  prominent, and a `Real` those whose prominence exceeds that fraction of their height.

- `pwindow` = `10`: the neighbourhood, in samples, over which a peak must be maximal. A noisy
  or finely resolved spectrum usually needs a smaller value than the default.

- `annotate` = `false`: label the marked peaks. `true` prints their coordinates; a function,
  or a tuple of one per coordinate, formats them. `textformat` post-processes that tuple.

- `nonnegative` = `true`: drop non-positive frequencies and densities, which a log axis cannot
  show.

- `average` = `median` and `width` = `(q₀.₂₅, q₀.₇₅)`: how a multivariate spectrum is reduced
  to a line and a band. `width` takes a number (a symmetric width), a pair of numbers, a
  function of each frequency's values, or a pair of such functions. `bandalpha` and
  `bandcolor` style the result.

_Other attributes are shared with `Makie.Lines`, `Makie.Scatter`, `Makie.Band` and
`Makie.Text`._

See also [`plotspectrum`](@ref), which sets log axes, limits and unit-aware labels to match.
"""
function spectrumplot end
function spectrumplot! end

"""
    plotspectrum(x; axis = (), kwargs...)

Plot a spectrum as [`spectrumplot`](@ref) does, into an axis that is additionally given log
scales, limits covering the positive data, and axis labels carrying the units of `x`.
Requires the `TimeseriesTools` extension (`using TimeseriesTools`).
"""
function plotspectrum end
function plotspectrum! end
export spectrumplot, spectrumplot!, plotspectrum, plotspectrum!

end
