@enum DIRTYPE :: UInt8 begin
    HALTON_DIRS = 1
    SOBOL_DIRS = 2
end

"""
    Settings(; kwargs...)

Return a mutable settings object for compilation of a problem for DFMO.

# Keyword arguments

* `alfa_stop :: Float64 = 1e-9`: minimum step length.
* `nf_max :: Integer = 2000`: maximum number of function evaluations.
* `iprint :: Integer = 0`: printing level. A value of `0` disables most console output.
* `hschoice :: DIRTYPE = DFMO_SOBOL_DIRS`: which directions to use.
* `dir_dense :: Bool = true`: whether to use dense direction or not.
* `dir_coord :: Bool = true`: whether to use coordinate directions or not.
"""
Base.@kwdef mutable struct Settings
    alfa_stop :: Float64 = 1e-9     # tolerance for step_length termination. 
                                    # DFMO will terminate as soon as all of the step_length 
                                    # fall below alfa_stop
    nf_max :: Integer = 2_000       # maximum number of allowed function evaluations
    iprint :: Integer = 0           # printing level. 0 - no console output, >0 different levels of printing
    hschoice :: DIRTYPE = SOBOL_DIRS    # which type of dense direction is used. 1 - HALTON-type, 2 - SOBOL-type
    dir_dense :: Bool = true        # whether to use the dense direction or not
    dir_coord :: Bool = true        # whether to use the coordinate directions or not
end

@batteries Settings selfconstructor=false

function parse_settings(settings)
    @unpack alfa_stop, nf_max, iprint, hschoice, dir_dense, dir_coord = settings
    return (
        alfa_stop,
        nf_max,
        iprint,
        Int(hschoice),
        dir_dense,
        dir_coord
    )
end