Base.@kwdef struct MOP{
    objectivesType,
    constraintsType
}
    num_vars :: Int = 0
    num_objectives :: Int = 0
    num_constraints :: Int = 0
    x0 :: Vector{Float64} = Float64[]

    lb :: Vector{Float64} = Float64[]
    ub :: Vector{Float64} = Float64[]

    objectives :: objectivesType
    constraints :: constraintsType = nothing

    num_calls_objectives :: Base.RefValue{Int} = Ref(0)
    num_calls_constraints :: Base.RefValue{Int} = Ref(0)
end

function mop_bound_vector_valid(b, bname="$(gensym())")
    if isempty(b) 
        @error "Bounds vector `$(bname)` empty."
        return false
    end
    if any(isinf.(b))
        @error "Bounds vector `$(bname)` not finite."
        return false
    end
    if any(isnan.(b))
        @error "Bounds vector `$(bname)` has NaN values."
        return false
    end
    return true
end

function check_mop(mop::MOP)
    @unpack num_vars, num_objectives, x0, num_constraints = mop
    if num_vars <= 0
        @error "Number of variables `num_vars` must be positive, is $(num_vars)."
        return nothing
    end
    if num_objectives <= 0
        @error "Number of objectives `num_objectives` must be positive, is $(num_objectives)."
        return nothing
    end
    if length(x0) != num_vars
        @error "Length of `x0` is $(length(x0)), but `num_vars` is $(num_vars)."
        return nothing
    end

    if num_constraints < 0
        @error "Number of constraints `num_constraints` should not be negative."
        return nothing
    end

    @unpack x0, lb, ub = mop
    if !mop_bound_vector_valid(lb, "lb")
        return nothing
    end
    if !mop_bound_vector_valid(ub, "ub")
        return nothing
    end
    if any(ub .< lb)
        @error "Upper and lower bounds not compatible."
        return nothing
    end

    if any(x0 .< lb) || any(ub .< x0)
        @warn "`x0` not conforming box constraints. Projecting it into box."
        _x0 = min.(max.(lb, x0), ub)
        x0 .= _x0
    end

    @info "Setting function call counters to zero."
    mop.num_calls_objectives[] = 0
    mop.num_calls_constraints[] = 0

    return mop
end

function setdim_closure(mop)
    @unpack num_vars, num_constraints, num_objectives = mop
    return function (n::Ptr{N}, m::Ptr{M}, q::Ptr{Q}) where {N, M, Q}
        unsafe_store!(n, convert(N, num_vars))
        unsafe_store!(m, convert(M, num_constraints))
        unsafe_store!(q, convert(Q, num_objectives))
        return nothing
    end
end

function startp_closure(mop)
    @unpack x0 = mop
    return function (n::N, _x::Ptr{X}) where{N, X}
        # make array accessible
        x = unsafe_wrap(Array, _x, n)
        # and copy `x0` into it
        copyto!(x, x0)
        return nothing
    end
end

#=
subroutine setbounds_abstract(n, lb, ub) bind(C)
    use, intrinsic :: iso_c_binding
    implicit none

    integer(c_int), value :: n
    real(c_double) :: lb(n)
    real(c_double) :: ub(n)
end subroutine
=#
function setbounds_closure(mop)
    @unpack lb, ub = mop
    return function (n::N, _lb::Ptr{L}, _ub::Ptr{U}) where {N, L, U}
        __lb = unsafe_wrap(Array, _lb, n)
        __ub = unsafe_wrap(Array, _ub, n)
        copyto!(__lb, lb)
        copyto!(__ub, ub)
        return nothing
    end
end
#=
subroutine functs_abstract(n, x, q, f) bind(C)
    use, intrinsic :: iso_c_binding
    implicit none
    
    integer(c_int), value :: n  ! vars
    integer(c_int), value :: q  ! objectives
    real(c_double) :: x(n)  ! input
    real(c_double) :: f(q)  ! output
end subroutine
=#
function functs_closure(mop)
    @unpack objectives = mop
    return function (n::N, _x::Ptr{X}, q::Q, _f::Ptr{F}) where{N, X, Q, F}
        @debug "OBJECTIVES CLOSURE CALLED."
        x = unsafe_wrap(Array, _x, n)
        fx = unsafe_wrap(Array, _f, q)
        copyto!(fx, objectives(x))
        return nothing 
    end
end
#=
subroutine fconstriq_abstract(n, m, x, ciq) bind(C)
    use, intrinsic :: iso_c_binding
    implicit none
    
    integer(c_int), value :: n  ! vars
    integer(c_int), value :: m  ! constraints
    real(c_double) :: x(n)  ! input
    real(c_double) :: ciq(m)  ! output
end subroutine
=#
function fconstriq_closure(mop)
    @unpack constraints = mop
    if isnothing(constraints)
        return fconstriq_dummy()
    end
    return function (n::N, m::M, _x::Ptr{X}, _ciq::Ptr{C}) where{N,M,X,C}
        x = unsafe_wrap(Array, _x, n)
        ciq = unsafe_wrap(Array, _ciq, m)
        copyto!(ciq, constraints(x))
        return nothing
    end
end

function fconstriq_dummy()
    return function (n::N, m::M, _x::Ptr{X}, _ciq::Ptr{C}) where{N,M,X,C}
        @debug "FCONSTRIQ DUMMY CALLED"
        return nothing
    end
end