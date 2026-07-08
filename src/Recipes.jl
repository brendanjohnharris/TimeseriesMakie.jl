using Makie
import Makie: Colorant

include("recipes/trail.jl")
include("recipes/kinetic.jl")
include("recipes/trajectory.jl")
include("recipes/shadows.jl")
include("recipes/traces.jl")

# neural / event recipes (base forms; specialised for TimeseriesTools arrays in the Tools ext and for
# Dewdrop solutions in Dewdrop's TimeseriesMakie ext)
include("recipes/spikeraster.jl")
include("recipes/psth.jl")
include("recipes/ratemap.jl")
