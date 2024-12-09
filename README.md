# DFMOWrapper.jl
## Call DFMO Derivative-Free Multi-Objective Optmizer from Julia

This package is motivated by a simple question:
Can we use Julia to pass a Matlab objective to the [DFMO](https://github.com/DerivativeFreeLibrary/DFMO) optimizer 
written in Fortran?
The answer is yes: By making certain subroutines C-compatible, and compiling a shared library, we 
can actually pass Julia callbacks (even closures!) to the optimizer.

## Installation
For now, you have to provide the DFMO source manually.
**Use this fork:**
```
https://github.com/manuelbb-upb/DFMO
```
Clone the repo or download and unpack the source, and note the location.
You don't need to compile anything yourself, but `gfortran` has to be available.
Moreover, the source location has to be writable!

This wrapper package is not registered, but you can add it as follows:
```julia
using Pkg
# `add` or `develop` from url:
Pkg.add(; url="https://github.com/manuelbb-upb/DFMOWrapper.jl")
```

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
The problem needs box constraints.
Box constraints have to be finite.
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
In this case, `res.x` is a matrix with result variable vectors as columns, and
`res.fx` are the objective values.
The field `res.fx_parsed` has the values as returned by DFMO (penalized?).
The vector `res.viol` has constraint violation values as returned by DFMO.
The number of function evaluations `res.num_evals` is returned by DFMO as well.
We count ourselves the number of objective function evaluations, `res.num_calls_objectives`,
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

The main routine in DFMO is not changed, execept that we have also made the algorithm
settings routine parameters.

To be honest, I don't really understand half of what I have done.
Some things are built on hope, others rely heavily on hidden Voodoo and automagic 
type conversions.
Garbage collection scares me, but the simple example runs without segmentation fault (for me).

## TODO

* Include constraint values in results.
* Interface for results.
* Test problems with nonlinear constraints.
* Test behavior for different return types.
* Use Artifact system for Fortran source.