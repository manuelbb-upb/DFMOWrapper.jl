module DFMOWrapper

## imports from standard library
import Libdl                    # working with shared library objects (compiled Fortran)

## helpers for structs and named tuples
import UnPack: @unpack
import StructHelpers: @batteries

include("settings.jl")
include("mop.jl")
include("utils.jl")

abstract type AbstractResult end
Base.@kwdef struct NoResult <: AbstractResult 
    msg :: String = ""
end

struct ParsedResult <: AbstractResult
    x :: Matrix{Float64}
    fx :: Matrix{Float64}
    fx_parsed :: Matrix{Float64}
    viol :: Vector{Float64}
    num_evals :: Int
    num_calls_objectives :: Int
    num_calls_constraints :: Int
end
@batteries ParsedResult

function optimize(
    mop;
    settings = Settings(; ),
    dfmo_path = "",
    res_dir = tempname(),
)
    mop = check_mop(mop)
    if isnothing(mop)
        return NoResult(; msg="`mop` not valid.")
    end
    dfmo_path = check_dfmo_path(dfmo_path)
    if isnothing(dfmo_path)
        return NoResult(; msg="`dfmo_path` not valid.")
    end

    res_dir = check_res_dir(res_dir)
    if isnothing(res_dir)
        return NoResult(; msg="`res_dir` not valid.")
    end

    (alfa_stop, nf_max, iprint, hschoice, dir_dense, dir_coord) = parse_settings(settings)
    # From `mop`, build functions that are provided as callback to DFMO.
    setdim_cls = setdim_closure(mop)
    startp_cls = startp_closure(mop)
    setbounds_cls = setbounds_closure(mop)
    functs_cls = functs_closure(mop)
    fconstriq_cls = fconstriq_closure(mop)

    # For these functions, we need pointers compatible with the Fortran/C interface:
    # The dollar sign enables pointers to closures without additional passthrough pointers.
    # But we have to be careful about garbage collection and use `GC.@preserve` below.
    setdim_cls_ptr = @cfunction $setdim_cls Cvoid (Ptr{Cint}, Ptr{Cint}, Ptr{Cint})
    startp_cls_ptr = @cfunction $startp_cls Cvoid (Cint, Ptr{Cdouble},)
    setbounds_cls_ptr = @cfunction $setbounds_cls Cvoid (Cint, Ptr{Cdouble}, Ptr{Cdouble},)
    functs_cls_ptr = @cfunction $functs_cls Cvoid (Cint, Ptr{Cdouble}, Cint, Ptr{Cdouble},)
    fconstriq_cls_ptr = @cfunction $fconstriq_cls Cvoid (Cint, Cint, Ptr{Cdouble}, Ptr{Cdouble},)

    dl_path = joinpath(dfmo_path, "multiobj.so")
    dl = Libdl.dlopen(dl_path)

    # Obtain pointers to "setter" functions to register callbacks
    set_setdim_ptr = setter_ptr(dl, :setdim)
    set_startp_ptr = setter_ptr(dl, :startp)
    set_setbounds_ptr = setter_ptr(dl, :setbounds)
    set_functs_ptr = setter_ptr(dl, :functs)
    set_fconstriq_ptr = setter_ptr(dl, :fconstriq)

    opt_ptr = Libdl.dlsym(dl, :opt_multiobj_)
    GC.@preserve setdim_cls_ptr startp_cls_ptr setbounds_cls_ptr functs_cls_ptr fconstriq_cls_ptr begin
         
        # "register" callback functions and turn them into fortran callables
        ccall(set_setdim_ptr, Cvoid, (Ptr{Cvoid},), setdim_cls_ptr)
        ccall(set_startp_ptr, Cvoid, (Ptr{Cvoid},), startp_cls_ptr)
        ccall(set_setbounds_ptr, Cvoid, (Ptr{Cvoid},), setbounds_cls_ptr)
        ccall(set_functs_ptr, Cvoid, (Ptr{Cvoid},), functs_cls_ptr)
        ccall(set_fconstriq_ptr, Cvoid, (Ptr{Cvoid},), fconstriq_cls_ptr)

        # run optimization:
        startdir = pwd()
        success = true
        try
            cd(res_dir)
            ccall(
                opt_ptr, 
                Cvoid, 
                (Ref{Cdouble},  Ref{Cint},  Ref{Cint},  Ref{Cint},      Ref{Bool},      Ref{Bool}),
                alfa_stop,      nf_max,     iprint,     hschoice,       dir_dense,      dir_coord
            )
        catch
            success = false
        finally
            cd(startdir)
        end
    end
    Libdl.dlclose(dl)

    if !success
        @warn "Call to DFMO not successful :("
        return NoResult(; msg="DFMO call failed.")
    end

    x, fx_parsed, viol, num_evals = read_dfmo_results(res_dir)
    fx = mapreduce(
        mop.objectives,
        hcat,
        eachcol(x)
    )
    return ParsedResult(
        x, fx, fx_parsed, viol, num_evals, mop.num_calls_objectives[], mop.num_calls_constraints[]
    )
end

end # module DFMOWrapper
