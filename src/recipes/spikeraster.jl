# ?------------------------------------ Spike raster ------------------------------------? #
"""
    spikeraster(times, ids; kwargs...)

Scatter a spike raster: one marker per spike at `(time, neuron)`, where `times[k]` and `ids[k]` are
the time and (integer) neuron index of the `k`-th spike.

Alternative single-argument inputs are accepted via `convert_arguments`:

- a vector of per-neuron spike-time vectors (`spikes[n]` = the spike times of neuron `n`);
- a `Neuron × Time` boolean matrix (a spike mask; columns index time).

## Key attributes:

- `sortby` = `false`: reorder neurons on the y-axis. `false` keeps the id order; `:rate` sorts by
  spike count; a `Function` maps each neuron's spike-time vector to a sort key; a vector supplies an
  explicit per-neuron key.

- `rev` = `false`: reverse the sort order.

_Other attributes are shared with `Makie.Scatter`._
"""
@recipe SpikeRaster (times, ids) begin
    """How to order neurons on the y-axis: `false` (id order), `:rate`, a function of a neuron's
    spike-time vector, or a vector of per-neuron sort keys."""
    sortby = false
    "Reverse the sort order."
    rev = false
    "Marker size (defaults smaller than `Scatter` for dense rasters)."
    markersize = 4
    get_drop_attrs(Scatter, [:markersize])...
end

function Makie.plot!(plot::SpikeRaster{<:Tuple{<:AbstractVector, <:AbstractVector}})
    map!(plot.attributes, [:times, :ids, :sortby, :rev], [:xs, :ys]) do times, ids, sortby, rev
        rows = _raster_rows(ids, times, sortby, rev)     # neuron id → y-row
        return (times, [rows[Int(id)] for id in ids])
    end
    scatter!(plot, plot.attributes, plot.xs, plot.ys; rasterize = pop_rasterize!(plot))
    return plot
end

# neuron id → y-row permutation from a sort spec. `false` keeps the natural order; otherwise build a
# per-neuron key and rank it (smallest key at the bottom), optionally reversed.
function _raster_rows(ids, times, sortby, rev)
    nn = isempty(ids) ? 0 : Int(maximum(ids))
    isempty(ids) || minimum(ids) >= 1 ||
        throw(ArgumentError("neuron ids index the y-axis and must be ≥ 1; got a minimum of $(minimum(ids))"))
    rows = sortby === false ? collect(1:nn) : invperm(sortperm(_raster_key(ids, times, sortby, nn)))
    rev && (rows = (nn + 1) .- rows)
    return rows
end

function _raster_key(ids, times, sortby, nn)
    if sortby === :rate                                  # spike count per neuron (∝ rate at fixed T)
        key = zeros(Int, nn)
        for id in ids
            key[Int(id)] += 1
        end
        return key
    elseif sortby isa AbstractVector
        length(sortby) == nn ||
            throw(ArgumentError("`sortby` has $(length(sortby)) entries but there are $nn neurons"))
        return collect(sortby)
    elseif sortby isa Function                           # f(neuron's spike-time vector)
        buckets = [eltype(times)[] for _ in 1:nn]
        for (t, id) in zip(times, ids)
            push!(buckets[Int(id)], t)
        end
        spiking = findall(!isempty, buckets)             # only call `sortby` on neurons that spiked
        isempty(spiking) && return zeros(nn)
        ks = float.(map(sortby, buckets[spiking]))
        key = fill(minimum(ks), nn)                      # silent neurons sort below the rest
        key[spiking] .= ks
        return key
    end
    throw(ArgumentError("`sortby` must be `false`, `:rate`, a function, or a vector; got $sortby"))
end

# per-neuron spike-time vectors → flat (times, ids)
function Makie.convert_arguments(::Type{<:SpikeRaster}, spikes::AbstractVector{<:AbstractVector{<:Real}})
    times = Float64[]
    ids = Int[]
    for (i, s) in enumerate(spikes)
        append!(times, s)
        append!(ids, fill(i, length(s)))
    end
    return (times, ids)
end

# Neuron × Time boolean mask → flat (times, ids); the column index is the (unitless) time
function Makie.convert_arguments(::Type{<:SpikeRaster}, S::AbstractMatrix{<:Bool})
    idx = findall(S)
    return ([float(I[2]) for I in idx], [I[1] for I in idx])
end
