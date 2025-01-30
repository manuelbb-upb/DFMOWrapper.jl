# DFMOWrapper.jl
## Call DFMO Derivative-Free Multi-Objective Optimizer from Julia

This package is motivated by a simple question:
Can we use Julia to pass a Matlab objective to the 
[DFMO](https://github.com/DerivativeFreeLibrary/DFMO) optimizer 
that is written in Fortran?
The answer is yes: By making certain subroutines C-compatible, and compiling a shared library, we 
can actually pass Julia callbacks (even closures!) to the optimizer.

## Installation

This wrapper package is not registered, but you can add it as follows:
```julia
using Pkg
# `add` or `develop` from url:
Pkg.add(; url="https://github.com/manuelbb-upb/DFMOWrapper.jl")
```

We now leverage the Julia artifact system to provide to obtain compiled shared library objects
from our [fork](https://github.com/manuelbb-upb/DFMO).
We support 64-bit Linux and Windows systems on `x86` architectures.
If you want to try to compile for a different environment, give it a try and call 
`optimize` with the `shared_lib_path` keyword argument. In case of success, please consider 
creating an informal pull request.

## Usage

You have to define a problem as a `DFMO.MOP`.
There is a keyword constructor.
Here is a problem with two quadratic objectives:
```julia
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
```
Every problem needs finite box constraints!
Nonlinear constraints can be defined with the keyword-argument `constraints`.
Both `objectives` and `constraints` take a single real vector and return a single
value vector.

* I have not yet tested what happens if you mix types. For now, best assume and return 
  `Float64`.
* Objects of type `DFMO.MOP` are immutable.  
  Use something like [Accessors.jl](https://github.com/JuliaObjects/Accessors.jl) for 
  interactive modifications.

When done, call `DFMO.optimize`:
```julia
res = DFMO.optimize(
    mop; 
    dfmo_path="/path/to/DFMO/source"
)
```
The result `res` is a `DFMO.AbstractResult`.
If something went wrong, then `res <: NoResult`.
Otherwise, `res <: Parsedresult`.
In this case:
* `res.x` is a matrix with result variable vectors as columns,
* and `res.fx` are the objective values.
* The field `res.cx` has the constraint function values at `x`.
* The field `res.rx` has the constraint violation values for the box constraints.  
  Column `j` has the values `max.(lb - res.x[:, j], res.x[:, j] .- ub)`.
* The field `res.viol` has the l1-penalty values based on `res.cx` and `res.bx`.  
  If an entry is positive, the respective column in `res.x` violates constraints.
* The field `res.fx_parsed` has the values as returned by DFMO (penalized?).
* The vector `res.viol_parsed` has constraint violation values as returned by DFMO.
* The number of function evaluations `res.num_evals` is returned by DFMO as well.  
  We count the number of objective function evaluations, `res.num_calls_objectives`,
  and the number of constraint function evaluations, `res.num_calls_constraints`.

## Internals

Originally, problems for DFMO have to be defined in a Fortran source file `problem.f90`.
We have now put the problem related definitions into their own Fortran modules, with
abstract C compatible interfaces for the important subroutines.
For every subroutine, there is also a setter function.
These are called from Julia.
A setter function takes a function pointer (such as returned by Julia's `@cfunction`),
makes it Fortran compatible (by means of `c_f_procpointer`) and stores the resulting
procedure pointer with "backwards"-compatible name.

The main routine in DFMO is not changed, except that we have also made the algorithm
settings routine parameters.

To be honest, I don't really understand half of what I have done.
Some things are built on hope, others rely heavily on hidden Voodoo and automagic 
type conversions.
Garbage collection scares me, but the simple example runs without segmentation fault (for me).

## TODO

* Improve logging, redirecting stdout.
* Interface for results.
* Test problems with nonlinear constraints.
* Test behavior for different return types.