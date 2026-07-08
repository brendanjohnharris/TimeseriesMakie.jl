# ?------------------------------------ Neural recipes (TimeseriesTools inputs) ------------------------------------? #
# Specialise the base neural recipes (SpikeRaster / PSTH / RateMap) for labelled TimeseriesTools spike
# trains: a binary `Neuron × Time` (or `Time × Neuron`) `ToolsArray`, from which the real time axis is
# read via the `𝑡` lookup. The recipes themselves live in TimeseriesMakie; here we only convert inputs.

# binary spike train → flat (times, ids), using the real time lookup
function Makie.convert_arguments(::Type{<:TimeseriesMakie.SpikeRaster}, S::AbstractToolsMatrix)
    td = DimensionalData.dimnum(S, 𝑡)
    t = lookup(S, td)
    idx = findall(!iszero, parent(S))
    if td == 2                                    # Neuron × Time
        return ([t[I[2]] for I in idx], [I[1] for I in idx])
    else                                          # Time × Neuron
        return ([t[I[1]] for I in idx], [I[2] for I in idx])
    end
end

# spike train → the pooled spike times for a PSTH
function Makie.convert_arguments(::Type{<:TimeseriesMakie.PSTH}, S::AbstractToolsMatrix)
    times, _ = Makie.convert_arguments(TimeseriesMakie.SpikeRaster, S)
    return (times,)
end

# spike train → (times, Neuron × Time matrix) for a rate map
function Makie.convert_arguments(::Type{<:TimeseriesMakie.RateMap}, S::AbstractToolsMatrix)
    td = DimensionalData.dimnum(S, 𝑡)
    t = collect(lookup(S, td))
    A = td == 2 ? parent(S) : permutedims(parent(S))       # → Neuron × Time
    return (t, A)
end
