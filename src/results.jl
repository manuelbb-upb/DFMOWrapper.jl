abstract type AbstractResult end

Base.@kwdef struct NoResult <: AbstractResult 
    msg :: String = ""
end

struct ParsedResult <: AbstractResult
    x :: Matrix{Float64}
    fx :: Matrix{Float64}
    cx :: Matrix{Float64}
    rx :: Matrix{Float64}
    viol :: Vector{Float64}
    fx_parsed :: Matrix{Float64}
    viol_parsed :: Vector{Float64}
    num_evals :: Int
    num_calls_objectives :: Int
    num_calls_constraints :: Int
end
@batteries ParsedResult

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