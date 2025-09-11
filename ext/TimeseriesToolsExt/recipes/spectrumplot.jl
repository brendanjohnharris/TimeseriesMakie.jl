import TimeseriesTools: findmaxima, peakproms
import TimeseriesTools: median, quantile

@recipe SpectrumPlot (f, s) begin
    cycle = [:color]

    "Mark the prominent peaks?"
    peaks = false

    "Window size for peak finding"
    pwindow = 10

    "Annotate peak values?"
    annotate = false

    "Formatter for peak text numbers"
    textformat = identity

    "Whether to filter non-negative points"
    nonnegative = true

    """The width or bounds of the error ribbon for multivariate spectra"""
    width = (Base.Fix2(quantile, 0.25), Base.Fix2(quantile, 0.75))
    """The averaging function for reducing over multivariate spectra"""
    average = median

    bandalpha = 0.5
    bandcolor = Makie.automatic

    textcolor = :black
    align = (:center, :bottom)

    get_drop_attrs(Lines, [:cycle])...
    get_drop_attrs(Scatter, attribute_names(Lines))...
    get_drop_attrs(Makie.Text,
                   [attribute_names(Scatter)..., attribute_names(Lines)..., :align])...
    get_drop_attrs(Makie.Band,
                   [
                       attribute_names(Scatter)...,
                       attribute_names(Lines)...,
                       attribute_names(Makie.Text)...
                   ])...
end

function Makie.plot!(plot::SpectrumPlot{<:Tuple{AbstractVector,
                                                AbstractArray}})
    map!(plot.attributes, [:f, :s, :nonnegative, :average, :width],
         [:x, :y, :yl, :yu, :doband]) do f, s, nn, average, width
        if size(s, 2) == 1 # We are ok with units, no band
            doband = false
        else
            doband = true
            f = ustripall(f)
            s = ustripall(s) # ! We can remove this once band! supports units
        end
        if size(s, 2) > 1
            if width isa Function
                width = map(width, eachrow(s))
            elseif width isa Tuple{Function, Function}
                width = (map(width[1], eachrow(s)),
                         map(width[2], eachrow(s)))
            end
            y = map(average, eachrow(s))
        else
            y = s
        end
        x = f

        yl = yu = y .* NaN
        if width isa Number && width > 0
            yl = y .- width / 2
            yu = y .+ width / 2
        elseif width isa Tuple{<:Number, <:Number}
            yl = y .- first(width)
            yu = y .+ last(width)
        elseif width isa Tuple{<:AbstractVector, <:AbstractVector}
            yl, yu = width
        end

        if nn
            idxs = (sign.(f) .> 0) .& (sign.(y) .> 0) # Sign for unitfuls
        else
            idxs = Colon()
        end
        x = f[idxs]
        y = y[idxs]
        yl = yl[idxs]
        yu = yu[idxs]
        return (x, y, yl, yu, doband)
    end

    map!(plot.attributes, [:x, :y, :peaks, :pwindow], [:p]) do x, y, peaks, pwindow
        if peaks === false
            return (Point2f[],)
        end
        pks, vals = findmaxima(y, pwindow) # Ignores uneven sampling
        if peaks === true
            peaks = length(pks)
        end
        pks, proms = peakproms(pks, y)
        if peaks isa Int
            peaks = min(peaks, length(pks))
            promidxs = partialsortperm(proms, 1:peaks, rev = true)
        elseif peaks isa Real
            promidxs = (proms ./ vals .> peaks) |> collect
        else
            return (Point2f[],)
        end
        pks = pks[promidxs]
        xp = x[pks]
        yp = y[pks]
        return (Point2f.(xp, yp),)
    end

    map!(plot.attributes, [:p, :annotate, :textformat], [:t]) do p, annotate, textformat
        if annotate === false || isempty(p)
            return (fill("", length(p)),)
        end
        if annotate === true
            annotate = (identity,)
        end
        if annotate isa AbstractVector
            annotate = Tuple(annotate)
        end
        if !(annotate isa Tuple)
            annotate = (annotate,)
        end
        if annotate isa Tuple
            annotate = textformat(annotate)
            text = map(p) do xy
                txt = map(annotate, xy) do a, x
                    if a isa Nothing
                        text = ""
                    elseif a isa String || a isa Symbol
                        text = "$x $a"
                    else # a is a function probably
                        text = x |> a |> string
                    end
                end
            end
            text = map(text) do t
                if length(t) == 1
                    return only(t)
                else
                    return "($(first(t)), $(last(t)))"
                end
            end
        end
        return (text,)
    end
    map!(plot.attributes, [:color, :bandcolor], [:parsed_bandcolor]) do color, bandcolor
        if bandcolor === Makie.automatic
            bandcolor = color
        end
        return (bandcolor,)
    end
    if plot.doband[]
        band!(plot, plot.attributes, plot[:x], plot[:yl], plot[:yu];
              color = plot[:parsed_bandcolor],
              alpha = plot[:bandalpha])
    end
    lines!(plot, plot.attributes, plot.attributes[:x], plot.attributes[:y])
    scatter!(plot.attributes, plot.attributes[:p])
    text!(plot, plot.attributes, plot[:p]; text = plot[:t], color = plot[:textcolor])
end

function Makie.convert_arguments(::Type{<:SpectrumPlot}, xy::AbstractVector{<:Point2})
    (map(first, xy), map(last, xy))
end

function Makie.convert_arguments(::Type{<:SpectrumPlot}, x::UnivariateSpectrum)
    decompose(x)
end
function Makie.convert_arguments(::Type{<:SpectrumPlot}, X::MultivariateSpectrum)
    (lookup(X, 𝑓), parent(X))
end

function Makie.convert_arguments(::Type{<:SpectrumPlot}, x::AbstractTimeseries)
    Makie.convert_arguments(SpectrumPlot, spectrum(x))
end

TimeseriesMakie.spectrumplot(args...; kwargs...) = spectrumplot(args...; kwargs...)
TimeseriesMakie.spectrumplot!(args...; kwargs...) = spectrumplot!(args...; kwargs...)

# * plotspectrum; modifies axis, not a recipe
function label_spectrum!(ax, f, s)
    uf = unit(eltype(f))
    ux = unit(eltype(s))
    f = ustripall.(f) |> collect
    s = ustripall.(s) |> collect
    if s isa AbstractMatrix
        ms = map(Base.Fix2(quantile, 0.1), eachrow(s))
    else
        ms = s
    end
    idxs = (f .> 0) .& (ms .> 0)
    setlims = ((minimum(f[idxs]), maximum(f[idxs])),
               (minimum(ms[idxs]), nothing))

    xax = first(ax.limits[])
    yax = last(ax.limits[])
    if isnothing(xax) || isnothing(yax)
        ax.limits = setlims
    end

    xax = first(ax.limits[])
    yax = last(ax.limits[])
    xax = first(xax)
    yax = first(yax)
    if isnothing(xax) || isnothing(yax) || xax <= 0 || yax <= 0
        ax.limits = setlims
    end

    ax.xscale = log10
    ax.yscale = log10
    uf == NoUnits ? (ax.xlabel = "Frequency") : (ax.xlabel = "Frequency ($uf)")
    ux == NoUnits ? (ax.ylabel = "Spectral density") :
    (ax.ylabel = "Spectral density ($ux)")
    return f, s
end
"""
    plotspectrum!(ax::Axis, x::UnivariateSpectrum)
Plot the given spectrum, labelling the axes, adding units if appropriate, and other niceties.
"""
function TimeseriesMakie.plotspectrum!(ax::Makie.Axis, s::UnivariateSpectrum;
                                       nonnegative = true, kwargs...)
    f, s = decompose(s)
    f, s = label_spectrum!(ax, f, s)
    spectrumplot!(ax, f, s; nonnegative, kwargs...)
end
function TimeseriesMakie.plotspectrum(s; axis = (), kwargs...)
    f = Figure()
    ax = Axis(f[1, 1]; xscale = log10, yscale = log10, axis...)
    p = TimeseriesMakie.plotspectrum!(ax, s; kwargs...)
    Makie.FigureAxisPlot(f, ax, p)
end

"""
    plotspectrum!(ax::Axis, x::MultivariateSpectrum)
Plot the given spectrum, labelling the axes, adding units if appropriate, and adding a band to show the iqr
"""
function TimeseriesMakie.plotspectrum!(ax::Makie.Axis, s::MultivariateSpectrum; kwargs...)
    f, v, s = decompose(s)
    f, s = label_spectrum!(ax, f, s)
    spectrumplot!(ax, f, s; nonnegative = true, kwargs...)
end

"""
    spectrumplot!(ax::Axis, x::AbstractVector, y::AbstractVector)
"""
# const ToolSpectrumPlot = SpectrumPlot{Tuple{<:UnivariateSpectrum}}
# argument_names(::Type{<: ToolSpectrumPlot}) = (:x,)

# function plot!(p::ToolSpectrumPlot)
#     x = collect(dims(p[:x], 𝑓))
#     y = collect(p[:x])
#     spectrumplot!(p, x, y)
#     p
# end

# """
#     plotLFPspectra(X::UnivariateTimeseries; slope=nothing, position=Point2f([5, 1e-5]), fs=nothing, N=1000, slopecolor=:crimson, kwargs...)

# Create a line frequency power (LFP) spectra plot for the given time series `X`.

# # Arguments
# - `slope`: The power-law slope. Default is `nothing`.
# - `position`: The position of the slope label. Default is `Point2f([5, 1e-5])`.
# - `fs`: The sampling frequency. Default is `nothing`.
# - `N`: The number of frequency bins. Default is `1000`.
# - `slopecolor`: The color of the slope line. Default is `:crimson`.
# - `kwargs...`: Additional keyword arguments to be passed to the plot.
# """
# function plotLFPspectra(X::UnivariateTimeseries; slope=nothing, position=Point2f([5, 1e-5]), fs=nothing, N=1000, slopecolor=:crimson, kwargs...)
#     times = collect(dims(X, 𝑡))
#     if isnothing(fs)
#         Δt = times[2] - times[1]
#         all(Δt .≈ diff(times)) || @warn "Violated assumption: all(Δt .≈ diff(times))"
#     else
#         Δt = 1/fs
#     end

#     P = [fp(Array(x)) for x ∈ eachcol(X)]
#     𝑓 = P[1].freq # Should be pretty much the same for all columns?
#     psd = hcat([p.power for p ∈ P]...)
#     psd = psd./(sum(psd, dims=1).*(𝑓[2] - 𝑓[1]))
#     psd = DimArray(psd, (𝑓𝑓), dims(X, :channel)))
#     fig = traces(𝑓, Array(psd); xlabel="𝑓 (Hz)", ylabel="Ŝ", title="Normalised power spectral density", smooth=1, yscale=log10, doaxis=false, domean=false, yminorgridvisible=false, kwargs...)
#     if !isnothing(slope)
#         _psd = psd[𝑓DD.Between(slope...))]
#         c, r, f = powerlawfit(_psd)
#         lines!(LinRange(slope..., 100), f(LinRange(slope..., 100)), color=slopecolor, linewidth=5)
#         text!(L"$\alpha$= %$(round(r, sigdigits=2))", position=Point2f0(position), fontsize=40)
#     end
#     return fig
# end
