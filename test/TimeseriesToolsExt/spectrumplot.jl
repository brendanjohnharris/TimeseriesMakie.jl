@testitem "SpectrumPlot" setup=[ToolsSetup] begin
    x = 0.1:0.1:12
    y = exp.(-(x .- 4) .^ 2) .+ exp.(-(x .- 8) .^ 2) .+ exp.(-(x .- 10) .^ 2)
    y = y .- minimum(y)

    f = Figure()
    ax = Axis(f[1, 1])
    TimeseriesMakie.spectrumplot!(ax, x, y, peaks = true, annotate = true,
                                  offset = (0, 3))
    display(f)
end

@testitem "SpectrumPlot TimeseriesTools" setup=[ToolsSetup] begin
    t = 0.005:0.005:1e4
    x = colorednoise(t*u"s") * u"V"
    s = spectrum(x)
    xticks = exp10.(range(log10(1), log10(100), length = 5))

    f = Figure(size = (1000, 1000))
    uc = Makie.UnitfulConversion(u"s^-1"; units_in_label = false)
    ax = Axis(f[1, 1]; dim1_conversion = uc, xscale = log10, yscale = log10,
              xticks)
    TimeseriesMakie.spectrumplot!(s[10:end], peaks = false, annotate = false,
                                  nonnegative = true)

    TimeseriesMakie.spectrumplot!(x, peaks = false, annotate = false,
                                  nonnegative = true, linestyle = :dash)

    display(f)

    X = ToolsArray([colorednoise(t[1:10:end]*u"s") .* i * u"V" for i in 1:10],
                   Var(1:10)) |>
        stack
    S = spectrum(X)
    f = Figure(size = (1000, 1000))
    ax = Axis(f[1, 1]; xscale = log10, yscale = log10,
              xticks)
    TimeseriesMakie.spectrumplot!(ax, S)
    display(f)

    TimeseriesMakie.plotspectrum(S)
end

@testitem "plotspectrum" setup=[ToolsSetup] begin
    using TimeseriesTools, CairoMakie, Unitful
    t = 0.005:0.005:1e5
    x = colorednoise(t*u"s") * u"V" # ::AbstractTimeseries

    f = Figure()
    ax = Axis(f[1, 1])
    S = powerspectrum(x, 0.001) # Second arguments sets frequency spacing
    plotspectrum!(ax, S)
    f
end
