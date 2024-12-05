function check_dfmo_path(p)
    if !isdir(p)
        @error "Path of DFMO not pointing to any directory."
        return nothing
    end

    dfmo_files = readdir(p)

    if !("makefile" in dfmo_files)
        @error "`makefile` missing in DFMO directory."
    end

    if !("multiobj.so" in dfmo_files)
        @info "No file `multiobj.so` in DFMO directory. Trying to make it."
        startdir = pwd()
        success = true
        try
            cd(p)
            run(`make clean`)
            run(`make shared`)
        catch
            @error "Could not `make` shared library. Is path writable? Is DFMO patched?"
            success = false
        finally
            cd(startdir)
        end
        !success && return nothing
    end

    if !("multiobj.so" in readdir(p))
        @error "Somehow, `multiobj.so` is still missing :("
        return nothing
    end
    return p
end

function setter_ptr(dl, funcsym)
    Libdl.dlsym(dl, Symbol(:set_, funcsym, :_ptr))
end

function check_res_dir(res_dir, fback=tempname())
    if !isdir(res_dir)
        try
            @info "There is (temporary) result dir at `$(res_dir)`. Trying to make it..."
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

function read_dfmo_results(base_path::AbstractString; delete_files=true)
    fobs_path = joinpath(base_path, "pareto_fobs.out")
    vars_path = joinpath(base_path, "pareto_vars.out")
    vars = Vector{Vector{Float64}}()
    fobs = Vector{Vector{Float64}}()
    viol = Vector{Float64}()
    for line in Iterators.drop(eachline(vars_path), 1)
        vals = [parse(Float64, s) for s in split(line, " ") if !isempty(s)]
        push!(vars, vals[1:end-1])
    end
    for line in Iterators.drop(eachline(fobs_path), 1)
        vals = [parse(Float64, s) for s in split(line, " ") if !isempty(s)]
        push!(fobs, vals[1:end-1])
        push!(viol, vals[end])
    end
    
    X = reduce(hcat, vars)
    F = reduce(hcat, fobs)
   
    fort_path = joinpath(base_path, "meta.out")
    reg =  r"number of function evaluations[^\d]*?(\d+)"
    num_evals = parse(Int, only(match(reg, read(fort_path, String)).captures))

	if delete_files
		rm(fobs_path, force=true)
		rm(vars_path, force=true)
		rm(fort_path, force=true)
	end
    return X, F, viol, num_evals
end