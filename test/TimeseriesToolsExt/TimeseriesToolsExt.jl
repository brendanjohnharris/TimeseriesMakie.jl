@testsnippet ToolsSetup begin
    using CairoMakie
    using DSP
    using Unitful
    using TimeseriesMakie
    using TimeseriesTools
    import TimeseriesTools: Timeseries
end

@testitem "Tools default" setup = [ToolsSetup] begin
    # `plottype` picks the recipe from the array's dimensionality
    x = colorednoise(0.1:0.1:12)
    p = plot(x)
    @test p.plot isa Makie.Lines

    x = Timeseries(randn(1000, 2), 0.01:0.01:10, 1:2)
    @test (@test_nowarn plot(x)).plot isa Makie.Heatmap
    # a lookup that is not contiguous still reaches the heatmap
    x = Timeseries(randn(1000, 2), 0.01:0.01:10, [1, 3])
    @test (@test_nowarn plot(x)).plot isa Makie.Heatmap

    # a spectrum is one-dimensional, so it reaches `lines` like a series does
    fs = 1000
    ts = Timeseries(sin.(2π * 50 .* range(0, 1, length = fs + 1)), range(0, 1, length = fs + 1))
    @test (@test_nowarn lines(powerspectrum(ts, fs / 100))).plot isa Makie.Lines
end

@testitem "Tools compatibility" setup = [ToolsSetup] begin
    # * Traces
    x = ToolsArray([colorednoise(0.1:0.1:12) for i in 1:6], Var(1:6)) |> stack
    p = @test_nowarn TimeseriesMakie.traces(decompose(x)...)
    @test p.plot isa Traces
    p = @test_nowarn TimeseriesMakie.traces(x)
    @test p.plot isa Traces
    # the conversion hands back both lookups and a plain matrix
    pargs = Makie.convert_arguments(Traces, x)
    @test pargs[1] == lookup(x, 1) |> collect
    @test pargs[2] == lookup(x, 2) |> collect
    @test pargs[3] isa Matrix

    # a multivariate unitful spectrum, stripped, on log axes
    t = 0.005:0.005:1.0e3
    U = ToolsArray([colorednoise(t * u"s") .* i * u"V" for i in 1:4], Var(1:4)) |> stack
    S = ustripall(spectrum(U)[2:10:end, :])
    f = Figure()
    ax = Axis(f[1, 1], xscale = log10, yscale = log10)
    @test_nowarn TimeseriesMakie.traces!(ax, S; colormap = :turbo)

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

    # `shadows!` with a ToolsArray matrix
    t = 0:0.1:10
    x2 = ToolsArray(sin.(t), 𝑡(t))
    y2 = x2 .^ 2
    z2 = y2 .* x2
    mat = hcat(parent(x2), parent(y2), parent(z2))
    Xmat = ToolsArray(mat, (𝑡(t), Var([:x, :y, :z])))
    f = Figure()
    ax = Axis3(f[1, 1])
    p = @test_nowarn shadows!(ax, Xmat; color = :gray, linewidth = 0.1)
    @test p isa Shadows

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
