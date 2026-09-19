# ?------------------------------------ Rate map ------------------------------------? #
"""
    ratemap(raster; kwargs...)
    ratemap(times, raster; kwargs...)

Per-neuron time-resolved firing rate as a `Neuron × Time` heatmap. `raster` is a `Neuron × Time`
matrix: a boolean spike mask or an already-computed rate field. `times` (optional) supplies the time
axis; without it the columns are indexed `1:ntime`. Time is coarse-grained into bins of `binwidth`
columns, each cell the mean over its bin.

## Key attributes:

- `binwidth` = `automatic`: number of time columns per bin (`automatic` = no binning).

_Other attributes are shared with `Makie.Heatmap`._
"""
@recipe RateMap (times, raster) begin
    "Number of time columns per bin (`automatic` = no binning)."
    binwidth = automatic
    get_drop_attrs(Heatmap, [])...
end

function Makie.plot!(plot::RateMap{<:Tuple{<:AbstractVector, <:AbstractMatrix}})
    map!(plot.attributes, [:times, :raster, :binwidth], [:xs, :ys, :Z]) do t, S, binwidth
        length(t) == size(S, 2) ||
            throw(DimensionMismatch("`times` has $(length(t)) entries but `raster` has $(size(S, 2)) columns"))
        b = binwidth === automatic ? 1 : clamp(Int(binwidth), 1, size(S, 2)) # ≥1 bin always
        Zb = _binmean(S, b)                          # neuron × nbins
        # ! `ustrip`: a unitful x sends Makie's heatmap conversion into infinite recursion
        return (ustrip.(_bincenters(t, b)), collect(1:size(Zb, 1)), permutedims(Zb))   # → (time, neuron, Z)
    end
    heatmap!(plot, plot.attributes, plot.xs, plot.ys, plot.Z; rasterize = pop_rasterize!(plot))
    return plot
end

# a bare Neuron × Time matrix → column-index time axis
Makie.convert_arguments(::Type{<:RateMap}, S::AbstractMatrix) = (collect(1:size(S, 2)), S)

# mean over non-overlapping bins of `b` columns (the trailing remainder is discarded)
function _binmean(S::AbstractMatrix, b::Integer)
    b <= 1 && return eltype(S) <: AbstractFloat ? S : float.(S)
    n = size(S, 2) ÷ b
    out = zeros(float(eltype(S)), size(S, 1), n)
    @inbounds for j in 1:n, i in 1:size(S, 1)
        acc = 0.0
        for c in ((j - 1) * b + 1):(j * b)
            acc += S[i, c]
        end
        out[i, j] = acc / b
    end
    return out
end

_bincenters(t::AbstractVector, b::Integer) = b <= 1 ? collect(t) :
    [sum(@view t[((j - 1) * b + 1):(j * b)]) / b for j in 1:(length(t) ÷ b)]
