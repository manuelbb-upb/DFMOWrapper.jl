module DFMOWrapper

## imports from standard library
import Libdl                    # working with shared library objects (compiled Fortran)

## helpers for structs and named tuples
import UnPack: @unpack
import StructHelpers: @batteries

const SHARED_LIB_EXT = @static if Sys.isunix()
    ".so"
else
    ".dll"
end
const SHARED_LIB_FILE = "multiobj" * SHARED_LIB_EXT

include("settings.jl")
include("mop.jl")
include("utils.jl")
include("results.jl")

function optimize(
    mop :: MOP;
    settings :: Settings = Settings(;),
    shared_lib_path :: Union{AbstractString, Nothing} = nothing,
    res_dir :: AbstractString = tempname(),
)
    mop = check_mop(mop)
    if isnothing(mop)
        return NoResult(; msg="`mop` not valid.")
    end
    res_dir = check_res_dir(res_dir)
    if isnothing(res_dir)
        return NoResult(; msg="`res_dir` not valid.")
    end
    shared_lib_path = get_shared_lib(shared_lib_path)

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

    success = true
    Libdl.dlopen(shared_lib_path) do dl
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
    end

    if !success
        @warn "Call to DFMO not successful :("
        return NoResult(; msg="DFMO call failed.")
    end

    x, fx_parsed, viol_parsed, num_evals = read_dfmo_results(res_dir)
    fx, cx, rx, viol, num_calls_objectives, num_calls_constraints = postprocess_results(x, mop)
    
    return ParsedResult(
        x, fx, cx, rx, viol, fx_parsed, viol_parsed, 
        num_evals, num_calls_objectives, num_calls_constraints
    )
end

end # module DFMOWrapper
