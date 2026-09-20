# ?------------------------------------ PSTH ------------------------------------? #
"""
    psth(times; kwargs...)

Peri-stimulus time histogram: bin spike `times` into a histogram of population activity over time.

## Key attributes:

- `binwidth` = `automatic`: bin width in time units (`automatic` uses the time range / 50).

- `normalization` = `:rate`: `:count` (spikes per bin) or `:rate` (spikes per unit time). With
  `nneurons` set, the rate is additionally divided by the neuron count (a per-neuron rate).

- `nneurons` = `automatic`: divide the rate by this many neurons (per-neuron normalisation).

_Other attributes are shared with `Makie.BarPlot`._
"""
@recipe PSTH (times,) begin
    "Bin width in time units (`automatic` = time range / 50)."
    binwidth = automatic
    "`:count` (spikes per bin) or `:rate` (spikes per unit time)."
    normalization = :rate
    "Divide the rate by this many neurons (`automatic` = no per-neuron scaling)."
    nneurons = automatic
    "Fraction of each bin left empty between bars."
    gap = 0
    get_drop_attrs(BarPlot, [:gap])...
end

function Makie.plot!(plot::PSTH{<:Tuple{<:AbstractVector}})
    map!(
        plot.attributes, [:times, :binwidth, :normalization, :nneurons],
        [:xs, :ys, :barwidth]
    ) do times, binwidth, normalization, nneurons
        centers, vals, w = _psth_bins(times, binwidth, normalization, nneurons)
        # ! `ustrip`: Makie's barplot rejects a unitful axis, and a `:rate` is per unit time
        return (ustrip.(centers), ustrip.(vals), ustrip(w))
    end
    # no `pop_rasterize!` here: BarPlot is itself a recipe, so `rasterize` warns either way
    barplot!(plot, plot.attributes, plot.xs, plot.ys; width = plot.barwidth)
    return plot
end

# bin `times` into non-overlapping bins of width `w`; return (bin centers, normalised values, w).
function _psth_bins(times, binwidth, normalization, nneurons)
    times = filter(isfinite, times) # a NaN time would poison `extrema` and the bin count
    isempty(times) && return (Float64[], Float64[], 1.0)
    lo, hi = extrema(times)
    w = binwidth === automatic ? (hi - lo) / 50 : float(binwidth)
    w > zero(w) || (w = oneunit(w)) # `zero`/`oneunit`, not `0`/`one`: times may carry units
    nb = max(1, ceil(Int, (hi - lo) / w))
    counts = zeros(Int, nb)
    for t in times
        counts[clamp(floor(Int, (t - lo) / w) + 1, 1, nb)] += 1
    end
    centers = [lo + (b - 0.5) * w for b in 1:nb]
    return (centers, _psth_norm(counts, w, normalization, nneurons), w)
end

function _psth_norm(counts, w, normalization, nneurons)
    if normalization === :count
        v = float.(counts)
    elseif normalization === :rate
        v = counts ./ w
    else
        throw(ArgumentError("`normalization` must be `:count` or `:rate`; got $normalization"))
    end
    nneurons === automatic || (v = v ./ nneurons)
    return v
end
