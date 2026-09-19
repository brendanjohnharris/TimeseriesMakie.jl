@testitem "Tools spike recipes" setup=[ToolsSetup] begin
    # a binary Neuron × Time spike train as a labelled ToolsArray (Var stands in for the neuron axis)
    nN, nT = 8, 100
    A = [rand() < 0.1 for _ in 1:nN, _ in 1:nT]

    # A `𝑡` lookup usually carries units in TimeseriesTools, so cover both; the recipes bin and
    # compare times arithmetically, which is where a bare `0` or `one` would break.
    for ts in (0.1:0.1:(0.1nT), (0.1:0.1:(0.1nT))u"s")
        S = ToolsArray(A, (Var(1:nN), 𝑡(ts)))

        p = TimeseriesMakie.spikeraster(S).plot          # → real spike times via the 𝑡 lookup
        @test p isa TimeseriesMakie.SpikeRaster
        @test length(p.xs[]) == count(A)

        p = TimeseriesMakie.psth(S; binwidth = oneunit(eltype(ts))).plot
        @test p isa TimeseriesMakie.PSTH
        @test sum(p.ys[]) > 0

        p = TimeseriesMakie.ratemap(S; binwidth = 5).plot
        @test p isa TimeseriesMakie.RateMap
        @test size(p.Z[]) == (nT ÷ 5, nN)
    end
end
