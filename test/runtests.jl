import DFMOWrapper as DW
using Test

ub = ones(2)
lb = -ub

x = [
    #1  2   3   4       5       6
    0   -1  0   -1.1    0       -2
    0   0   1   0       1.1     3
]

rx = DW._pp_rx(x, lb, ub)

@assert rx ≈ [
    -1      0       -1      0.1     -1      1
    -1      -1      0       -1      0.1     2
]

cx = Matrix{Float64}(undef, 0, 6)
viol = DW._pp_viol(rx, cx)
@test viol ≈ [0, 0, 0, 0.1, 0.1, 2]

cx = [
    -1 0 1 -1 0 1;;
]
viol = DW._pp_viol(rx, cx)
@test viol ≈ [0, 0, 1, 0.1, 0.1, 2]

cx = DW._pp_cx(nothing, x)
@assert size(cx) == (0, 6)

cfunc = x -> sum(x.^2) - 2 - 1e-10
cx = DW._pp_cx(cfunc, x)
@assert all(cx[1, 1:5] .<= 0)
@assert cx[1, 6] ≈ 11

viol = DW._pp_viol(rx, cx)
@assert viol ≈ [0, 0, 0, 0.1, 0.1, 11]