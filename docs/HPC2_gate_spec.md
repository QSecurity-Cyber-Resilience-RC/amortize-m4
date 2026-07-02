# HPC2 multiplication gadget - specification for a distribution-level checker

This is the exact gadget used in gadgets.c (hpc2_and), written tool-agnostically
so it transfers to SILVER or fullVerif for an independent PINI check. IronMask
cannot verify it (see STATUS_AND_VERIFICATION.md); use a checker that models NOT
gates and computes actual distributions.

## Gate-level definition (probing / software model, no register stages)

Inputs: sharings a = (a_0..a_{n-1}), b = (b_0..b_{n-1}).
Randoms: r_{i,j} for i < j, fresh and uniform; define r_{j,i} = r_{i,j}
         (symmetric), n(n-1)/2 random bits total.

For each output share i:
    z_i := a_i AND b_i
    for each j != i:
        c1  := (NOT a_i) AND r_{i,j}
        bm  := b_j XOR r_{i,j}
        c2  := a_i AND bm
        z_i := z_i XOR c1 XOR c2

Output: z = (z_0 .. z_{n-1}), a sharing of a AND b.

Every wire (a_i, b_i, r_{i,j}, NOT a_i, c1, bm, c2, and each partial z_i) is a
probe point. The bare product a_i AND b_j is never computed as a wire; the
contribution c1 XOR c2 = a_i*b_j XOR r_{i,j} is a randomness-masked value.

## Correctness

XOR over all domains: the r_{i,j} appear in domains i and j once each and cancel;
the products sum to (XOR_i a_i)(XOR_j b_j) = a AND b. Verified in selftest.c at
orders 1..8.

## Property to check

t-PINI at your target order t (n = t + 1 shares). Established in [CGLS21]. A
SILVER Verilog module realizes each line above as NOT / AND / XOR gates; for the
software probing model use the combinational (no-register) form. For the
glitch-robust hardware model, place each AND output behind a register, which is
the HPC2 form analyzed in [CGLS21].

## For reference: 2-share instance (order 1)

  na0 = NOT a0
  w1  = na0 AND r01
  m0  = b1  XOR r01
  w2  = a0  AND m0
  cross0 = w1 XOR w2
  z0  = (a0 AND b0) XOR cross0

  na1 = NOT a1
  u1  = na1 AND r01
  m1  = b0  XOR r01
  u2  = a1  AND m1
  cross1 = u1 XOR u2
  z1  = (a1 AND b1) XOR cross1
