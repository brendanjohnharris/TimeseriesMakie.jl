@testitem "Tools spike recipes" setup=[ToolsSetup] begin
    # a binary Neuron × Time spike train as a labelled ToolsArray (Var stands in for the neuron axis)
    nN, nT = 8, 100
    A = [rand() < 0.1 for _ in 1:nN, _ in 1:nT]
    S = ToolsArray(A, (Var(1:nN), 𝑡(0.1:0.1:(0.1nT))))

    p = TimeseriesMakie.spikeraster(S)          # → real spike times via the 𝑡 lookup
    @test p.plot isa TimeseriesMakie.SpikeRaster
    p = TimeseriesMakie.psth(S; binwidth = 1.0)
    @test p.plot isa TimeseriesMakie.PSTH
    p = TimeseriesMakie.ratemap(S; binwidth = 5)
    @test p.plot isa TimeseriesMakie.RateMap
end
