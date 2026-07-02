# Option B: HPC2 multiplication and the PINI composition, status (final)

## Decision

Stay with Option B. The multiplication is HPC2, a PINI multiplication; the
construction composes on PINI (contribution C2, trivial composition). We cite
HPC2's proven PINI from the literature and verify the remaining gadgets and
functional correctness with the tools in hand. This keeps the paper's narrative
intact and does not require adopting a new verifier.

## What was wrong originally

Theorem 1 composed on PINI, and its proof sketch asserted that an SNI gadget is
in particular PINI. That is false; SNI and PINI are incomparable. The ISW
multiplication is SNI but not PINI: its cross-term wire a_i*b_j depends on two
share indices, which a single-index PINI budget cannot cover, so it leaks at
order one. The student's IronMask run caught exactly this.

## What was verified here (IronMask, built from source)

- ISW multiplication, 2 shares: 1-SNI, NOT 1-PINI. Reproduces the student's
  result exactly.
- No complement-free multiplication shipped with IronMask is PINI (ISW,
  Crypto2020/DOM, mult-ref all fail). A PINI multiplication needs a complemented
  wire, which is what HPC2 uses.
- linear_refresh, encoded faithfully to the C (last share updated incrementally,
  so a2^r0 is a live wire): 2-NI, NOT 2-SNI, but 2-PINI. Matches the student's
  SNI failure and, importantly, shows linear_refresh is PINI.
- refresh_sni, faithful: 2-NI, 2-SNI, and 2-PINI.
- Functional correctness of the full conversion with HPC2 inside ks_add: passes
  at orders 1 through 8 for both the sequential and tree variants (selftest.c).

## Why HPC2 is not verified in IronMask, and why that is fine

This matters, so it is stated precisely. IronMask cannot verify HPC2, and the
reason is fundamental, not a parser detail.

1. The student's original run did not fail PINI; it errored on the constant 1
   and produced no verdict.
2. Patching IronMask's parser to accept the complement (a + 1) makes it run, and
   it then returns "not 1-PINI." That verdict is a false positive.
3. IronMask flags a single wire, cross_0_1 = ((~a0)&r) ^ (a0&(b1^r)). That wire
   equals a0*b1 ^ r, which over uniform r is a fair coin for every value of the
   secret, hence perfectly simulatable. This was checked exhaustively over GF(2).
4. The reason IronMask flags it: it represents each multiplication as an opaque
   product term and can only follow masking that enters linearly. HPC2's mask
   does not enter linearly; it arises from the public constant distributing
   through the AND, (~a)*r = r ^ a*r, so the two cross-term products cancel and
   leave a fresh r on top of a*b. IronMask's abstraction cannot see that
   cancellation. The tell is that the complemented and de-complemented gadgets
   return the identical verdict; a tool that saw the complement would not.

IronMask is therefore the wrong tool for HPC2. It is well suited to gadgets whose
masking is linear randomness, which is why it certifies ISW's SNI correctly.
HPC2's t-PINI is proven in the literature [CGLS21] and is checkable in a
distribution-level verifier (SILVER, fullVerif). We adopt the published result.

## The fix in code

hpc2_and replaces isw_and inside ks_add, so both conversions route through it.
Symmetric randoms r_ij = r_ji, n(n-1)/2 per multiplication, the same count as
ISW, so the benchmarks barely move. The cross term into domain i is
((~a_i)&r_ij) ^ (a_i&(b_j^r_ij)); it equals a_i*b_j ^ r_ij, so correctness is
unchanged, but the bare product a_i*b_j never appears on a wire.

Under PINI composition the pieces are: HPC2 (PINI, cited); share-wise XOR
(trivially PINI); linear_refresh at the tree merges (2-PINI, verified here);
refresh_sni (2-PINI, verified here). The refreshes are fine as they stand; only
the multiplication changed, and the linear_refresh SNI failure is irrelevant
under PINI composition.

## Verification story for the paper

Use the paragraph in THEOREM1_correction.md. In short: cite HPC2's PINI from
[CGLS21]; state the refresh gadgets were verified PINI (and the SNI baseline of
ISW) with IronMask; state functional correctness was checked at orders 1 to 8.
The internal reason IronMask does not verify HPC2 does not belong in the paper;
it is recorded here for your own record and in case a reviewer asks, in which
case the answer is that HPC2's PINI is established in [CGLS21] and can be
re-checked in SILVER.

## Optional independent check of HPC2

If you or a reviewer want an in-house machine-check of HPC2 itself, use SILVER or
fullVerif, which model NOT gates and compute actual distributions. verify/
contains the exact gate structure (HPC2_gate_spec.md and hpc2_2.sage) ready to
transfer.

## Files

  gadgets.c, gadgets.h   HPC2 wired into ks_add; isw_and retained but unused.
  selftest.c             correctness test, passes d=1..8 for both variants.
  bench_m4_raw.c         unchanged interface; A2B entry points route through HPC2.
  analyze_cycles_v2.py   the provenance gate for the cycle measurements.
  verify/                gadget structures verified here, plus the HPC2 gate
                         spec for a distribution-level checker.
