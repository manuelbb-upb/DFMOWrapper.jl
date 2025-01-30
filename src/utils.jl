using Pkg.Artifacts
function get_shared_lib(::Nothing)
    global SHARED_LIB_FILE
    slib_dir = artifact"shared_libs"
    return joinpath(slib_dir, SHARED_LIB_FILE)
end

function get_shared_lib(fpath)
    global SHARED_LIB_FILE, SHARED_LIB_EXT
    if isdir(fpath)
        fpath = joinpath(fpath, SHARED_LIB_FILE)
    end
    if !isfile(fpath)
        @warn "The requested file `$(fpath)` could not be found. Using artifacts."
        return get_shared_lib(nothing)
    end
    @assert last(splitext(fpath)) == SHARED_LIB_EXT "Extension of shared library file must be `$(SHARED_LIB_EXT)`."
    return fpath
end

function setter_ptr(dl, funcsym)
    Libdl.dlsym(dl, Symbol(:set_, funcsym, :_ptr))
end

function check_res_dir(res_dir, fback=tempname())
    if !isdir(res_dir)
        try
            @info "There is no (temporary) result dir at `$(res_dir)`. Trying to make it..."
            mkpath(res_dir)
        catch
            @warn "Could not make result dir! Trying `$(fback)`."
            if !isnothing(fback)
                return check_res_dir(fback, nothing)
            else
                return fback
            end
        end
    end
    return res_dir
end

function postprocess_results(x, mop)
    fx = mapreduce(mop.objectives, hcat, eachcol(x))
    cx = _pp_cx(mop.constraints, x)
    @unpack lb, ub = mop
    rx = _pp_rx(x, lb, ub)
    viol = _pp_viol(rx, cx)
    
    return fx, cx, rx, viol, mop.num_calls_objectives[], mop.num_calls_constraints[]
end

function _pp_cx(::Nothing, x)
    return Matrix{Float64}(undef, 0, size(x, 2))
end
function _pp_cx(cfunc, x)
    return mapreduce(cfunc, hcat, eachcol(x))
end

function _pp_rx(x, lb, ub)
    return mapreduce(ξ -> max.(lb .- ξ, ξ .- ub), hcat, eachcol(x))
end

function _pp_viol(rx, cx)
    return vec(max.(0, maximum(cx; dims=1, init=0.0), maximum(rx; dims=1, init=0.0)))
end