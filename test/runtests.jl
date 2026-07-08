using Test
using TestItems
using TestItemRunner

@run_package_tests

@testsnippet Setup begin
    using CairoMakie
    using CairoMakie.Makie.PlotUtils
    using Statistics
    using LinearAlgebra
    using TimeseriesMakie
    using CairoMakie.Makie.Distributions
    using LaTeXStrings
end

@testitem "Kinetic" setup=[Setup] begin
    x = range(-4π, 4π, length = 10000)
    y = sinc.(x)
    f = Figure()
    ax = Axis(f[1, 1])
    kinetic!(ax, x, y; linewidthscale = 0.5, linewidth = :curv, linecap = :round)
    display(f)
    save("recipes/kinetic.png", f)
end

@testitem "Trail 2D" setup=[Setup] begin
    f = Figure(size = (400, 400))

    ϕ = 0:0.1:(8π) |> reverse
    x = ϕ .* exp.(ϕ .* im)
    y = imag.(x)
    x = real.(x)

    # * Default
    ax = Axis(f[1, 1], title = "Default")
    trail!(ax, x, y)

    # * Colormap
    ax = Axis(f[1, 2], title = "Colormap")
    trail!(ax, x, y; color = 1:500)

    # * Alpha
    ax = Axis(f[2, 1], title = "Alpha^3")
    trail!(ax, x, y; alpha = Base.Fix2(^, 3))

    # * Shorter trail
    ax = Axis(f[2, 2], title = "Shorter trail")
    trail!(ax, x, y; n_points = 100)

    linkaxes!(contents(f.layout))
    hidedecorations!.(contents(f.layout))
    save("recipes/trail.png", f)

    # * Animation
    f = Figure(size = (300, 300))
    r = 50
    ax = Axis(f[1, 1], limits = ((-r, r), (-r, r)))
    xy = Observable([Point2f(first.([x, y]))])
    p = trail!(ax, xy, n_points = 100)
    hidedecorations!(ax)

    record(f, "recipes/trail_animation.mp4", zip(x, y)) do _xy
        xy[] = push!(xy[], Point2f(_xy))
    end
end

@testitem "Trajectory" setup=[Setup] begin
    f = Figure(size = (400, 400))

    ϕ = 0:0.1:(8π) |> reverse
    x = ϕ .* exp.(ϕ .* im)
    y = imag.(x)
    x = real.(x)

    # * Default
    ax = Axis(f[1, 1], title = "Default")
    trajectory!(ax, x, y)

    # * Speed
    ax = Axis(f[1, 2], title = "Speed")
    trajectory!(ax, x, y; color = :speed)

    # * Alpha
    ax = Axis(f[2, 1], title = "Time")
    trajectory!(ax, x, y; color = :time)

    # * 3D
    ax = Axis3(f[2, 2], title = "3D")
    trajectory!(ax, x, y, x .* y; color = :speed)

    hidedecorations!.(contents(f.layout))
    save("recipes/trajectory.png", f)

    # * Animation
    f = Figure(size = (300, 300))
    r = 50
    ax = Axis(f[1, 1], limits = ((-r, r), (-r, r)))
    X = Point3f.(zip(x, y, x .* y))
    xyz = Observable(X[[1]])
    p = trajectory!(ax, xyz, color = :speed)
    hidedecorations!(ax)

    record(f, "recipes/trajectory_animation.mp4", X) do _xyz
        xyz[] = push!(xyz[], _xyz)
    end
end

@testitem "Shadows" setup=[Setup] begin
    f = Figure(size = (400, 400))

    ϕ = 0:0.1:(8π) |> reverse
    x = ϕ .* exp.(ϕ .* im)
    y = imag.(x)
    x = real.(x)
    z = x .* y

    # * Default
    limits = (extrema(x), extrema(y), extrema(z))
    ax = Axis3(f[1, 1]; title = "Shadows", limits)
    lines!(ax, x, y, z)
    shadows!(ax, x, y, z; limits, linewidth = 0.5, color = :gray)

    hidedecorations!.(contents(f.layout))
    save("recipes/shadows.png", f)

    # * Animation
    f = Figure(size = (200, 200))
    ax = Axis3(f[1, 1]; limits)
    X = Point3f.(zip(x, y, z))
    xyz = Observable(X[[1]])
    lines!(ax, xyz)
    shadows!(ax, xyz; limits, color = :gray, linewidth = 0.1)
    hidedecorations!(ax)

    record(f, "recipes/shadows_animation.mp4", X) do _xyz
        xyz[] = push!(xyz[], _xyz)
    end
end

@testitem "Traces" setup=[Setup] begin
    f = Figure(size = (800, 200))

    x = 0:0.1:10
    y = range(0, π, length = 5)
    Z = [sin.(x .+ i) for i in y]
    Z = stack(Z)

    ax = Axis(f[1, 1]; title = "Unstacked")
    p = traces!(ax, x, y, Z)
    Colorbar(f[1, 2], p)

    ax = Axis(f[1, 3]; title = "Even")
    p = traces!(ax, x, y, Z; spacing = :even, offset = 1.5)
    Colorbar(f[1, 4], p)

    ax = Axis(f[1, 5]; title = "Close")
    p = traces!(ax, x, y, Z; spacing = :close, offset = 1.5)
    Colorbar(f[1, 6], p)

    save("recipes/traces.png", f)
end

@testitem "SpikeRaster" setup=[Setup] begin
    times = [1.0, 2.0, 2.5, 5.0, 6.0, 6.5, 7.0]
    ids = [1, 2, 1, 3, 2, 3, 1]

    f = Figure(size = (600, 400))
    spikeraster!(Axis(f[1, 1]; title = "Flat"), times, ids)
    spikeraster!(Axis(f[1, 2]; title = "Sorted by rate"), times, ids; sortby = :rate, rev = true)
    spikeraster!(Axis(f[2, 1]; title = "Vector-of-vectors"), [[1.0, 2.0, 4.0], [3.0], Float64[]])
    spikeraster!(Axis(f[2, 2]; title = "Bool matrix"), [rand() < 0.2 for _ in 1:8, _ in 1:40])
    save("recipes/spikeraster.png", f)
    @test isfile("recipes/spikeraster.png")
end

@testitem "PSTH" setup=[Setup] begin
    times = repeat(1.0:10.0, inner = 8)
    f = Figure(size = (600, 200))
    psth!(Axis(f[1, 1]; title = "Count"), times; binwidth = 1.0, normalization = :count)
    psth!(Axis(f[1, 2]; title = "Rate"), times; binwidth = 2.0, normalization = :rate)
    save("recipes/psth.png", f)
    @test isfile("recipes/psth.png")
end

@testitem "RateMap" setup=[Setup] begin
    S = [rand() < 0.15 for _ in 1:20, _ in 1:200]
    f = Figure(size = (600, 200))
    ratemap!(Axis(f[1, 1]; title = "Bin index"), S; binwidth = 10)
    ratemap!(Axis(f[1, 2]; title = "Real time"), collect(1:200) .* 0.1, S; binwidth = 10)
    save("recipes/ratemap.png", f)
    @test isfile("recipes/ratemap.png")
end
