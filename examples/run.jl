import DFMOWrapper as DFMO
using GLMakie

mop = DFMO.MOP(;
    num_vars = 2,
    num_objectives = 2,
    num_constraints = 0,
    x0 = rand(2),
    lb = fill(-2.0, 2),
    ub = fill(2.0, 2),
    objectives = function (x)
        return [
            (x[1] - 1.0)^2 + (x[2] - 1.0)^2,
            (x[1] - 1.0)^2 + (x[2] + 1.0)^2,
        ]
    end
)

res = DFMO.optimize(
    mop; 
    dfmo_path=joinpath(ENV["HOME"], "Coding", "DFMO")
)