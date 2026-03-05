module TimeseriesToolsExt
using TimeseriesTools
using TimeseriesTools.Unitful
using Makie
using TimeseriesMakie
import TimeseriesMakie: get_drop_attrs
import Makie: attribute_names, convert_arguments
import TimeseriesTools: AbstractToolsArray

"""
    decompose(x::Union{<:AbstractTimeseries, <:AbstractSpectrum})
Convert a time series or spectrum to a tuple of the dimensions and the data (as `Array`s).
"""
function Makie.GeometryBasics.decompose(x::AbstractToolsArray)
    return map(parent, lookup(x))..., parent(x)
end

# function Makie.convert_arguments(::Type{<:AbstractPlot}, x::AbstractTimeseries)
#     decompose(x)
# end

# * Define plot types (see DimensionalData/ext/DimensionalDataMakie.jl)
const AbstractToolsVector = AbstractToolsArray{T, 1} where {T}
const AbstractToolsMatrix = AbstractToolsArray{T, 2} where {T}
const MayObs{T} = Union{T, Makie.Observable{<:T}}
const MakieGrids = Union{Makie.GridPosition, Makie.GridSubposition}

Makie.plottype(::D) where {D <: Union{<:AbstractToolsArray}} = _plottype(D)
_plottype(::Type{<:MayObs{AbstractToolsVector}}) = Makie.Lines
_plottype(::Type{<:MayObs{AbstractToolsMatrix}}) = Makie.Heatmap
_plottype(::Type{<:MayObs{AbstractToolsArray{<:Any, 3}}}) = Makie.Volume
for DD in (AbstractToolsVector, AbstractToolsMatrix, AbstractToolsArray{<:Any, 3})
    p = _plottype(DD)
    f = Makie.plotkey(p)
    f! = Symbol(f, '!')
    eval(quote
             Makie.plot(dd::MayObs{$DD}; kwargs...) = Makie.$f(dd; kwargs...)
             function Makie.plot(fig::MakieGrids, dd::MayObs{$DD}; kwargs...)
                 Makie.$f(fig, dd; kwargs...)
             end
             Makie.plot!(ax, dd::MayObs{$DD}; kwargs...) = Makie.$f!(ax, dd; kwargs...)
         end)
end

# * Conversions
function Makie.convert_arguments(::Type{<:AbstractPlot}, x::AbstractToolsVector{<:Point})
    parent(x) |> tuple
end
function Makie.convert_arguments(P::Type{TimeseriesMakie.Traces},
                                 A::DimensionalData.AbstractDimMatrix)
    return decompose(A)
end
function Makie.convert_arguments(P::Type{TimeseriesMakie.Shadows}, A::AbstractMatrix)
    if size(A, 2) != 3
        throw(ArgumentError("`shadows` requires a 2D matrix with 3 columns, got $(size(A))"))
    end
    pts = map(Point3f, eachrow(A))
    return (pts,)
end

function Makie.convert_arguments(P::Type{TimeseriesMakie.Shadows},
                                 A::AbstractToolsArray{<:Any, 2})
    return Makie.convert_arguments(P, parent(A))
end

include("recipes/spectrumplot.jl")

end
