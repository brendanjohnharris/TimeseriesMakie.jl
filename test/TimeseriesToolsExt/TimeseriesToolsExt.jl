@testsnippet ToolsSetup begin
    using CairoMakie
    using DSP
    using Unitful
    using TimeseriesMakie
    using TimeseriesTools
end

@testitem "Tools default" setup=[ToolsSetup] begin
    x = colorednoise(0.1:0.1:12)
    p = plot(x)
    @test p.plot isa Makie.Lines
end

@testitem "Tools compatibility" setup=[ToolsSetup] begin
    # * Traces
    x = ToolsArray([colorednoise(0.1:0.1:12) for i in 1:6], Var(1:6)) |> stack
    p = @test_nowarn TimeseriesMakie.traces(decompose(x)...)
    @test p.plot isa Traces
    p = @test_nowarn TimeseriesMakie.traces(x)
    @test p.plot isa Traces

    # * Kinetic
    x = ToolsArray(sin.(0.1:0.1:12), 𝑡(0.1:0.1:12))
    p = @test_nowarn TimeseriesMakie.kinetic(x)
    @test p.plot isa Kinetic

    # * Shadows
    y = x .^ 2
    z = y .* x
    p = @test_nowarn TimeseriesMakie.shadows(x, y, z)
    @test p.plot isa Shadows
    X = ToolsArray([x, y, z], Var(1:3)) |> stack
    p = @test_nowarn TimeseriesMakie.shadows(X)
    @test p.plot isa Shadows

    # * Trail
    p = @test_nowarn TimeseriesMakie.trail(x, y)
    @test p.plot isa Trail
    p = @test_nowarn TimeseriesMakie.trail(x, y, z)
    @test p.plot isa Trail

    # * Trajectory
    p = @test_nowarn TimeseriesMakie.trajectory(x, y)
    @test p.plot isa Trajectory
    p = @test_nowarn TimeseriesMakie.trajectory(x, y, z)
    @test p.plot isa Trajectory
end
