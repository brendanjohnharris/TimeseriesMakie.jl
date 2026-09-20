using Test
using TestItems
using TestItemRunner

@run_package_tests

@testsnippet Setup begin
    # Makie wraps errors raised inside a recipe's `map!` in a `ResolveException`, so match on the
    # message rather than the type.
    function throws_with(f, msg)
        try
            f()
            return false
        catch e
            return occursin(msg, sprint(showerror, e))
        end
    end

    using CairoMakie
    import CairoMakie.Makie
    using CairoMakie.Makie.PlotUtils
    using Statistics
    using LinearAlgebra
    using TimeseriesMakie
    using CairoMakie.Makie.Distributions
    using LaTeXStrings
    using Unitful
end

@testitem "Kinetic" setup = [Setup] begin
    x = range(-4π, 4π, length = 10000)
    y = sinc.(x)
    f = Figure()
    ax = Axis(f[1, 1])
    kinetic!(ax, x, y; linewidthscale = 0.5, linewidth = :curv, linecap = :round)
    display(f)
    # ! CairoMakie paints a mesh through a Cairo mesh pattern, which is not anti-aliased, so a
    # thin `:mesh` stroke steps visibly. Raster it finer; this one goes in the README.
    save("recipes/kinetic.png", f; px_per_unit = 4)

    # one width per point feeds every geometry
    @test kinetic(1:10, 1:10; linewidth = 3).plot.pointwidths[] == fill(3.0, 10)
    @test kinetic(1:3, [0.0, 1.0, 0.0]; linewidth = :y).plot.pointwidths[] ≈ [1, 11, 1]
    @test kinetic(
        1:3, [0.0, 1.0, 0.0]; linewidth = :y,
        widthrange = (2, 6)
    ).plot.pointwidths[] ≈ [2, 6, 2]
    # the pipeline is lazy: read the node so the `map!` actually runs
    @test throws_with(
        () -> kinetic(1:3, 1:3; linewidth = :nope).plot.pointwidths[],
        "linewidth must be"
    )

    for mode in (:curv, :x, :y)
        w = kinetic(1:10, 1:10; linewidth = mode, geometry = :segments).plot.linewidths[]
        @test length(w) == 18 && all(isfinite, w)
    end
    # nothing crowds an open straight line, so it draws at the full width throughout
    @test allequal(kinetic(1:10, 1:10).plot.pointwidths[])
    @test !allequal(kinetic(x, y; geometry = :segments).plot.linewidths[])

    # a segment takes the mean of its two point widths, each repeated over the pair
    @test TimeseriesMakie.segmentwidths([1.0, 11.0, 1.0]) ≈ [6.0, 6.0, 6.0, 6.0]

    # too few points to measure any crowding, and a lone point's degenerate segment
    @test length(kinetic([0.0, 1.0], [0.0, 2.0]; geometry = :segments).plot.linewidths[]) == 2
    @test length(kinetic([0.0], [0.0]; geometry = :segments).plot.linewidths[]) == 2
    @test length(kinetic(1:10, 1:10; linewidth = 3, geometry = :segments).plot.linewidths[]) ==
        18

    # a NaN break must not poison the arc length and leave every width NaN
    w = kinetic([0.0, 1.0, NaN, 3.0, 4.0], [0.0, 1.0, NaN, 1.0, 0.0]).plot.pointwidths[]
    @test length(w) == 5 && all(isfinite, w)
end

@testitem "Kinetic crowding" setup = [Setup] begin
    # `ballradius` has to reproduce both closed forms: a tight turn and a near miss are meant to
    # be the same measurement of how much room the curve has
    φ = range(0, 2π, length = 400)[1:(end - 1)]
    for R in (5.0, 40.0, 200.0)
        r = TimeseriesMakie.ballradius(R .* cos.(φ), R .* sin.(φ), 1.0e6)
        @test all(≈(R; rtol = 1.0e-5), r[2:(end - 1)]) # the open ends have a one-sided normal
    end
    d = 7.0
    X = vcat(range(0, 300, length = 500), range(300, 0, length = 500))
    Y = vcat(fill(0.0, 500), fill(d, 500))
    @test all(≈(d / 2; rtol = 1.0e-6), TimeseriesMakie.ballradius(X, Y, 1.0e6)[100:400])

    # the slope limit stays under its bound and never exceeds its rate
    b = [10.0, 10, 10, 1, 10, 10, 10]
    w = TimeseriesMakie.slopelimit(b, collect(0.0:6.0), 2.0)
    @test w ≈ [7, 5, 3, 1, 3, 5, 7]
    @test all(w .<= b) && maximum(abs, diff(w)) <= 2 + 1.0e-9

    t = range(0, 1, length = 3000)
    burst = sin.(2π .* 1.5 .* t) .+
        0.45 .* sin.(2π .* 45 .* t) .* exp.(-((t .- 0.5) ./ 0.04) .^ 2)
    f = Figure(size = (900, 300))
    p = kinetic!(Axis(f[1, 1]), t, burst)
    Makie.colorbuffer(f) # resolve the projection the widths are measured in
    w = p.pointwidths[]
    inside = abs.(t .- 0.5) .< 0.06
    @test mean(w[inside]) < 0.4 * mean(w[.!inside]) # the burst is the crowded part
    @test maximum(abs, diff(w)) < 1 # and it gets there gradually

    # `crowding` is the fraction of the available room the stroke fills
    @test mean(kinetic(t, burst; crowding = 0.25).plot.pointwidths[]) <
        mean(kinetic(t, burst; crowding = 1.0).plot.pointwidths[])
    # `widthrange` bounds the result
    w = kinetic(t, burst; widthrange = (2, 6)).plot.pointwidths[]
    @test minimum(w) >= 2 - 1.0e-9 && maximum(w) <= 6 + 1.0e-9
    # a lower `taper` flattens the profile
    @test std(kinetic(t, burst; taper = 0.005).plot.pointwidths[]) <
        std(kinetic(t, burst; taper = 0.2).plot.pointwidths[])
end

@testitem "Kinetic stroke mesh" setup = [Setup] begin
    using TimeseriesMakie: strokemesh

    # a horizontal line of constant width fills a band of that width, with round caps of radius w/2
    P = Point2f.(0:10:100, 0)
    V, F, S = strokemesh(P, fill(6.0, length(P)))
    @test maximum(last, V) - minimum(last, V) ≈ 6 atol = 1.0e-3   # quads are exact
    @test minimum(first, V) ≈ -3 atol = 0.2                     # caps are polygons: 0.2 px chord
    @test maximum(first, V) ≈ 103 atol = 0.2
    @test length(S) == length(V) && all(in(eachindex(P)), S)
    @test all(f -> all(in(eachindex(V)), f), F)

    # the taper is linear between the two end widths
    V, _, _ = strokemesh(Point2f[(0, 0), (100, 0)], [2.0, 10.0])
    @test maximum(abs(v[2]) for v in V if abs(v[1]) < 1.0e-3) ≈ 1 atol = 1.0e-3
    @test maximum(abs(v[2]) for v in V if abs(v[1] - 100) < 1.0e-3) ≈ 5 atol = 1.0e-3

    # a right-angle turn gets a fan on the outer corner and nothing on the inner side
    V, _, S = strokemesh(Point2f[(0, 0), (50, 0), (50, 50)], fill(10.0, 3))
    corner = Point2f(50, 0)
    ring = [v for (v, s) in zip(V, S) if s == 2 && abs(norm(v - corner) - 5) < 1.0e-3]
    @test any(v -> v[1] > 50 && v[2] < 0, ring)
    @test !any(v -> v[1] < 50 - 1.0e-3 && v[2] > 1.0e-3, ring)

    # a turn too small to open a visible gap emits no fan
    straight = strokemesh(Point2f[(0, 0), (50, 0), (100, 0)], fill(4.0, 3))[2]
    nearly = strokemesh(Point2f[(0, 0), (50, 0), (100, 0.01)], fill(4.0, 3))[2]
    @test length(nearly) == length(straight)

    # degenerate input: a lone point is a dot, repeated points and NaNs do not poison the mesh
    V, F, _ = strokemesh([Point2f(3, 4)], [2.0])
    @test !isempty(F)
    @test all(v -> abs(norm(v - Point2f(3, 4)) - 1) < 1.0e-3 || v == Point2f(3, 4), V)
    V, _, _ = strokemesh(Point2f[(0, 0), (0, 0), (10, 0)], fill(2.0, 3))
    @test all(v -> all(isfinite, v), V)
    V, _, _ = strokemesh(Point2f[(0, 0), (10, 0), (NaN, NaN), (20, 0), (30, 0)], fill(2.0, 5))
    @test all(v -> all(isfinite, v), V)
end

@testitem "Kinetic stroke outline" setup = [Setup] begin
    # a uniform colour draws as one filled outline, which CairoMakie anti-aliases; a per-point
    # colour needs the triangles, which it paints through a mesh pattern and leaves hard-edged
    x = range(-4π, 4π, length = 2000)
    y = sinc.(x)
    f = Figure(size = (600, 300))
    ax = Axis(f[1, 1])
    hidedecorations!(ax)
    hidespines!(ax)
    p = kinetic!(ax, x, y; linewidth = 6)
    @test Makie.plotkey(typeof(p.plots[1])) === :poly
    @test length(p.strokerings[]) == 1
    @test Makie.plotkey(typeof(kinetic(1:50, sin.(1:50); color = 1:50).plot.plots[1])) === :mesh

    # the regression this exists for: more than two grey levels across the edge
    mktempdir() do dir
        file = joinpath(dir, "outline.png")
        save(file, f)
        img = CairoMakie.FileIO.load(file)
        shades = unique(round.(Float64.(CairoMakie.Colors.red.(img[:, 600])), digits = 2))
        @test length(shades) > 2
    end

    # a NaN breaks the stroke into separate rings, and a lone point closes into a dot
    pn = kinetic([0.0, 1.0, NaN, 3.0, 4.0], [0.0, 1.0, NaN, 1.0, 0.0]).plot
    Makie.colorbuffer(current_figure())
    @test length(pn.strokerings[]) == 2
    p1 = kinetic([0.0], [0.0]).plot
    Makie.colorbuffer(current_figure())
    @test length(p1.strokerings[]) == 1 && length(only(p1.strokerings[])) > 3
    # repeated points carry no direction, so they must not produce an empty or NaN ring
    pr = kinetic(zeros(5), zeros(5)).plot
    Makie.colorbuffer(current_figure())
    @test length(pr.strokerings[]) == 1 && all(all(isfinite, v) for v in only(pr.strokerings[]))
end

@testitem "Kinetic mesh anti-aliasing" setup = [Setup] begin
    # ! TEMPORARY, paired with ext/CairoMakieAntiAliasExt.jl: delete both once CairoMakie
    # ! anti-aliases a 2D mesh itself. The assertion stays true either way, so it is safe to
    # ! leave until then.
    x = range(-4π, 4π, length = 400)
    y = sinc.(x)
    blue = Makie.RGBf(0.2, 0.4, 0.8)
    levels = map((blue, fill(blue, 400))) do colour # scalar takes the outline, vector the mesh
        f = Figure(size = (600, 300))
        ax = Axis(f[1, 1])
        hidedecorations!(ax)
        hidespines!(ax)
        kinetic!(ax, x, y; linewidth = 8, color = colour)
        mktempdir() do dir
            file = joinpath(dir, "aa.png")
            save(file, f)
            img = CairoMakie.FileIO.load(file)
            return length(unique(round.(Float64.(CairoMakie.Colors.red.(img[:, 600])), digits = 2)))
        end
    end
    # without the workaround the mesh gives exactly two: the stroke colour and the background
    @test all(>(2), levels)
end

@testitem "Kinetic geometry" setup = [Setup] begin
    # CairoMakie cannot stroke a varying width, so `:auto` picks the pixel-space mesh
    @test TimeseriesMakie.autogeometry() === :mesh
    @test kinetic(1:10, 1:10).plot.plots[1] isa Poly            # uniform colour: one outline
    @test kinetic(1:5, 1:5; color = 1:5).plot.plots[1] isa Mesh # per-point colour: triangles
    @test kinetic(1:10, 1:10; geometry = :segments).plot.plots[1] isa LineSegments
    @test throws_with(() -> kinetic(1:3, 1:3; geometry = :nope), "geometry must be")

    # :lines hands the per-point widths to one `lines!`, which GLMakie renders natively
    p = kinetic(1:10, 1:10; geometry = :lines).plot
    @test p.plots[1] isa Lines && length(p.plots[1].linewidth[]) == 10
    # widths are pixels, so limits come from the points alone
    @test Makie.widths(Makie.data_limits(p))[1:2] ≈ [9, 9]

    # the stroke is w pixels wide however anisotropic the axis
    f = Figure(size = (200, 800))
    ax = Axis(f[1, 1]; limits = (0, 10, -1.0e-3, 1.0e-3))
    p = kinetic!(ax, 0:10, zeros(11); linewidth = 4, geometry = :mesh, color = 1:11)
    Makie.colorbuffer(f) # resolves the camera and the projected nodes
    ys = last.(p.strokeverts[])
    @test maximum(ys) - minimum(ys) ≈ 4 atol = 1.0e-2
    @test Makie.widths(Makie.data_limits(p))[1] ≈ 10 # pixel geometry never leaks into limits

    # zooming changes the projected points, not the pixel width
    ax.limits = (0, 5, -1, 1)
    Makie.colorbuffer(f)
    ys = last.(p.strokeverts[])
    @test maximum(ys) - minimum(ys) ≈ 4 atol = 1.0e-2

    # per-point colours expand onto the emitted vertices
    fap = kinetic(1:5, 1:5; color = 1:5, geometry = :mesh)
    Makie.colorbuffer(fap.figure)
    @test length(fap.plot.strokecolor[]) == length(fap.plot.strokeverts[])

    # sparse points and alpha below 1 are where the mesh earns its keep
    f = Figure(size = (600, 300))
    x = range(-4π, 4π, length = 40)
    y = sinc.(x)
    kinetic!(
        Axis(f[1, 1]; title = ":segments"), x, y; linewidthscale = 2,
        color = (:black, 0.4), geometry = :segments
    )
    kinetic!(
        Axis(f[1, 2]; title = ":mesh"), x, y; linewidthscale = 2,
        color = (:black, 0.4), geometry = :mesh
    )
    save("recipes/kinetic_mesh.png", f)
end

@testitem "Trail 2D" setup = [Setup] begin
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

    # A scalar alpha is a uniform transparency, not a profile: it must not be normalised, and
    # must not be read as a one-element collection that truncates the trail.
    p = trail(1:10, 1:10; alpha = 0.5).plot
    @test p.final_n_points[] == 10
    @test all(==(0.5), p.processed_alpha[])
    @test trail(1:10, 1:10; alpha = identity).plot.processed_alpha[][[1, end]] == [0.0, 1.0]

    # A constant colour vector has no range to normalise; it must pick one real colour rather
    # than a transparent `NaN` sample.
    c = trail(1:10, 1:10; color = ones(10)).plot.final_color[]
    rgb(q) = (q.r, q.g, q.b)
    @test allequal(rgb.(c))
    @test any(!=((0, 0, 0)), rgb.(c))
    @test !allequal(rgb.(trail(1:10, 1:10; color = collect(1.0:10)).plot.final_color[]))

    @test throws_with(() -> trail(1:10, 1:10; color = :red).plot.final_color[], "must be a number")
end

@testitem "Trajectory" setup = [Setup] begin
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

@testitem "Shadows" setup = [Setup] begin
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

    # `swapshadows` is documented to take a single Bool for all three planes, not just a tuple
    @test shadows(1:10, 1:10, 1:10; swapshadows = true).plot.xs[][1][1] ≈ 10
    @test shadows(1:10, 1:10, 1:10; swapshadows = false).plot.xs[][1][1] ≈ 1
    @test shadows(1:10, 1:10, 1:10).plot.xs[][1][1] ≈ 10        # automatic = (true, true, false)

    # unitful coordinates and limits (stripped, since `Point3f` cannot carry units)
    @test length(shadows((1:5)u"m", (1:5)u"m", (1:5)u"m").plot.xs[]) == 5
    lims = ((1.0u"m", 5.0u"m"), (1.0u"m", 5.0u"m"), (1.0u"m", 5.0u"m"))
    @test length(shadows(1:5, 1:5, 1:5; limits = lims).plot.xs[]) == 5
end

@testitem "Traces" setup = [Setup] begin
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

    # A numeric spacing stacks cumulatively, as `:even` and `:close` do; it is a gap between
    # neighbours, not one constant offset applied to every trace.
    Z0 = repeat(collect(1.0:5), 1, 3)
    @test vec(minimum(traces(1:5, 1:3, Z0; spacing = 10.0).plot.stacked_Z[], dims = 1)) ==
        [1.0, 11.0, 21.0]
    @test vec(minimum(traces(1:5, 1:3, Z0).plot.stacked_Z[], dims = 1)) == [1.0, 1.0, 1.0]
    @test length(traces(1:5, 1:1, zeros(5, 1); spacing = :even).plot.stacked_Z[]) == 5
    @test throws_with(
        () -> traces(1:5, 1:3, zeros(5, 3); spacing = :nope).plot.stacked_Z[],
        "must be a number"
    )

    # colours are generated per plotted point, and the points are `zip`ped to the shorter of the two
    p = traces(1:5, 1:2, zeros(10, 2))
    @test length(p.plot.final_x[]) == length(p.plot.final_color[])
end

@testitem "SpikeRaster" setup = [Setup] begin
    times = [1.0, 2.0, 2.5, 5.0, 6.0, 6.5, 7.0]
    ids = [1, 2, 1, 3, 2, 3, 1]

    f = Figure(size = (600, 400))
    spikeraster!(Axis(f[1, 1]; title = "Flat"), times, ids)
    spikeraster!(Axis(f[1, 2]; title = "Sorted by rate"), times, ids; sortby = :rate, rev = true)
    spikeraster!(Axis(f[2, 1]; title = "Vector-of-vectors"), [[1.0, 2.0, 4.0], [3.0], Float64[]])
    spikeraster!(Axis(f[2, 2]; title = "Bool matrix"), [rand() < 0.2 for _ in 1:8, _ in 1:40])
    save("recipes/spikeraster.png", f)
    @test isfile("recipes/spikeraster.png")

    # ids index the y-axis, and a `sortby` vector supplies one key per neuron; both are checked
    # up front rather than surfacing as a `BoundsError` from the row lookup.
    @test throws_with(() -> spikeraster([1.0], [0]).plot.ys[], "≥ 1")
    @test throws_with(() -> spikeraster(times, ids; sortby = [1.0]).plot.ys[], "neurons")

    # a `sortby` function is only handed the neurons that actually spiked
    @test length(TimeseriesMakie._raster_rows([10, 10, 3], [1.0, 2.0, 0.5], first, false)) == 10
end

@testitem "PSTH" setup = [Setup] begin
    times = repeat(1.0:10.0, inner = 8)
    f = Figure(size = (600, 200))
    psth!(Axis(f[1, 1]; title = "Count"), times; binwidth = 1.0, normalization = :count)
    psth!(Axis(f[1, 2]; title = "Rate"), times; binwidth = 2.0, normalization = :rate)
    save("recipes/psth.png", f)
    @test isfile("recipes/psth.png")

    # unitful spike times: the bin width is compared against `zero(w)`, not a bare `0`
    @test length(psth((1.0:10.0)u"s").plot.xs[]) > 0
    @test length(psth(fill(2.0u"s", 5)).plot.xs[]) > 0        # a single distinct time
    @test length(psth([1.0, NaN, 2.0, 3.0]).plot.xs[]) > 0    # a non-finite time is dropped
end

@testitem "RateMap" setup = [Setup] begin
    S = [rand() < 0.15 for _ in 1:20, _ in 1:200]
    f = Figure(size = (600, 200))
    ratemap!(Axis(f[1, 1]; title = "Bin index"), S; binwidth = 10)
    ratemap!(Axis(f[1, 2]; title = "Real time"), collect(1:200) .* 0.1, S; binwidth = 10)
    save("recipes/ratemap.png", f)
    @test isfile("recipes/ratemap.png")

    # a `binwidth` wider than the raster still yields one bin, rather than zero bins and a
    # `BoundsError` from the empty time axis
    @test size(ratemap(rand(Bool, 3, 4); binwidth = 10).plot.Z[]) == (1, 3)
    @test size(ratemap(rand(Bool, 3, 7); binwidth = 2).plot.Z[]) == (3, 3)
    @test throws_with(() -> ratemap(collect(1.0:3), rand(Bool, 3, 7)).plot.Z[], "columns")
end
