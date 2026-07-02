# AMORTIZE Cortex-M4 Benchmark and Verification Artifact

This repository contains the working artifact for the AMORTIZE masked
conversion study. It has two connected parts:

- a Cortex-M4 firmware project for measuring masked gadget costs on an
  STM32F407 target, and
- a Docker-friendly verification testbench that generates IronMask inputs from
  the project gadgets and records verification transcripts.

The repository is also a record of the project's verification story. The first
version of the construction tried to compose an ISW multiplication gadget under
PINI. The verification work showed the gap: ISW is SNI, but SNI and PINI are
incomparable, and ISW is not PINI. The current construction therefore routes
the masked Kogge-Stone adder through `hpc2_and`, an HPC2 multiplication gadget
whose PINI property is established in the CGLS21 literature. IronMask is still
used for the gadgets it models well, and the Cortex-M4 firmware measures the
actual implementation that uses HPC2.

## Project Story

The work started from the practical question: how expensive is the masked
arithmetic-to-Boolean conversion on a real Cortex-M4, and can the security
claims behind the gadget composition be checked in a reproducible way?

The M4 side answers the cost question. The firmware in `boardinit/` runs the
conversion on an STM32F407 at 24 MHz, uses the DWT cycle counter, pulls
fresh randomness from the STM32 RNG, and prints UART CSV blocks for sequential
and tree conversion variants. The measured cycle summary currently lives in
`docs/m4_cycles.csv`.

The verification side answers the artifact question. The Python runner in
`verification/` reads the implementation schedule in `gadgets.c`, generates
IronMask `.sage` files, runs IronMask, and saves raw transcripts plus CSV
summaries under `results/`.

The important correction is documented in
`docs/STATUS_AND_VERIFICATION.md`. The original proof sketch needed PINI
composition and treated SNI as if it implied PINI. IronMask caught the problem:
ISW multiplication verifies as SNI but fails PINI. The implementation now uses
HPC2 multiplication inside `ks_add`. The cross term used by HPC2 is:

```text
((~a_i) & r_ij) ^ (a_i & (b_j ^ r_ij))
```

This equals `a_i*b_j ^ r_ij`, so correctness is preserved, but the bare product
`a_i*b_j` is never materialized as a probeable wire. The exact gate-level
description is in `docs/HPC2_gate_spec.md`.

## Repository Map

`boardinit/` is the STM32F407 Cortex-M4 firmware project. The main project
files are:

- `boardinit/Core/Src/gadgets.c`: masked gadget implementation, including
  `hpc2_and`, `isw_and`, refresh gadgets, `ks_add`, and sequential/tree A2B.
- `boardinit/Core/Inc/gadgets.h`: public gadget interfaces and target notes.
- `boardinit/Core/Src/bench_step2_audit.c`: audit benchmark with raw cycle,
  RNG, checksum, and stack-watermark output.
- `boardinit/Core/Src/init.c`: 24 MHz clock setup, GPIO, and USART2 setup.
- `boardinit/CMakePresets.json` and `boardinit/CMakeLists.txt`: CMake/Ninja
  build configuration for the ARM embedded target.
- `boardinit/LAB_GUIDE.md`: the longer lab guide for M4 benchmarking, formal
  verification, and TVLA planning.

`verification/` is the formal-verification workspace. It contains:

- `verification/IronMask/`: the IronMask source tree and compiled tool location
  expected by the Docker workflow.
- `verification/evaluate.sh`: the top-level verification launcher used inside
  the container.
- `verification/run_step3_ironmask_hpc2_og.py`: the active artifact generator
  used by `evaluate.sh`.
- `verification/gadgets/gadgets.c`: a container-side gadget path; Docker
  overlays the firmware `gadgets.c` here.

`docs/` contains project notes and supporting artifacts:

- `docs/STATUS_AND_VERIFICATION.md`: the current verification narrative and
  status.
- `docs/HPC2_gate_spec.md`: exact HPC2 gate-level specification for SILVER or
  fullVerif-style distribution-level checking.
- `docs/m4_cycles.csv`: measured M4 cycle summary for sequential and tree
  variants.
- ChipWhisperer purchase/support documents for the TVLA phase.

`results/` contains generated verification artifacts. A typical run directory
contains:

- `verification_metadata.txt`: source hash, IronMask path, max order, jobs,
  timeout, and runner notes.
- `verification_summary.csv`: one row per gadget/property/order check.
- `ironmask_inputs/`: generated `.sage` files.
- `transcripts/`: raw IronMask command outputs and hand/composition notes.

## Local Docker Testbench

The Docker testbench is intended for the formal-verification part of the
artifact. It uses an Ubuntu 22-style x86 container with a compiled IronMask
binary and mounts this repository's verification resources into `/work`.

### Prerequisites

- Docker and Docker Compose.
- A local copy of this repository.
- Access to GitHub Container Registry for the prebuilt image
  `ghcr.io/ali63yavari/m4_ubuntu_x86_host:latest`.
- Enough resources for combinatorial verification. The compose file currently
  asks for 8 CPUs, 12 GB memory, and 20 GB memory plus swap.

The Docker image export is intentionally not stored in this repository; exported
image archives are ignored and are not part of the artifact checkout. Pull the
image from GitHub Container Registry, then tag it with the local name expected by
`docker-compose.yml`:

```bash
docker pull ghcr.io/ali63yavari/m4_ubuntu_x86_host:latest
docker tag ghcr.io/ali63yavari/m4_ubuntu_x86_host:latest m4_ubuntu_x86_host:latest
docker images | grep m4_ubuntu_x86_host
```

`backup/ironmask_test.tar.gz` is a source/archive backup, not the Docker image
referenced by `docker-compose.yml`.

### Start the Container

From the repository root:

```bash
docker compose up -d
docker ps --filter name=m4_x86_ubuntu
docker exec -it m4_x86_ubuntu bash
```

Inside the container, the working directory is `/work`:

```bash
cd /work
ls
```

The compose file mounts:

- host `./verification` as container `/work`
- host `./boardinit/Core/Src/gadgets.c` as `/work/gadgets/gadgets.c`
- host `./results` as `/work/results`

That overlay is deliberate: the verification runner checks the same gadget
implementation used by the M4 firmware.

### Run Verification

Inside the container:

```bash
cd /work
./evaluate.sh --max-order 3
```

`evaluate.sh` creates a timestamped output directory under `/work/results` and
currently launches:

```bash
python3 /work/run_step3_ironmask_hpc2_og.py \
  --ironmask /work/IronMask/src/ironmask \
  --gadgets-c /work/gadgets/gadgets.c \
  --out-dir /work/results/<timestamp>_verification \
  --max-order 3 \
  --jobs 4 \
  --timeout 840000 \
  --include-pini
```

For a quick health check after the run:

```bash
ls /work/results/*_verification
cat /work/results/*_verification/verification_metadata.txt
cat /work/results/*_verification/verification_summary.csv
```

On the host, inspect the same files under `results/`.

## M4 Hardware Benchmarking

The hardware benchmark targets the STM32F407G-DISC1 Discovery board. The basic
setup is:

- STM32F407G-DISC1 board.
- Mini-USB cable for power/ST-LINK.
- 3.3 V USB-to-TTL serial adapter for USART2 output.
- `gcc-arm-none-eabi`, `binutils-arm-none-eabi`, CMake/Ninja or STM32CubeIDE,
  OpenOCD/ST-LINK tools, and a serial terminal.

The firmware configures the target for a 24 MHz system clock in
`boardinit/Core/Src/init.c`, uses USART2 at 115200 baud, and uses the DWT cycle
counter for cycle measurements. `gadgets.c` expects `rand32()` to provide fresh
randomness; the benchmark implementations wire this to the STM32 RNG.

The audit benchmark in `boardinit/Core/Src/bench_step2_audit.c` prints two CSV
blocks:

```text
BEGIN_M4_CYCLES_RAW
variant,order,run,cycles_per_poly,rng_calls,rng_wait_cycles,checksum,stack_bytes
...
END_M4_CYCLES_RAW

BEGIN_M4_CYCLES_SUMMARY
variant,order,runs,median_cycles_per_poly,cycles_per_coeff,stack_bytes
...
END_M4_CYCLES_SUMMARY
```

The current checked-in summary in `docs/m4_cycles.csv` reports 11 measured runs
per order for both `seq` and `tree` variants, with orders 1 through 8. The tree
variant uses more stack as the recursion grows, so keep the target stack large;
the existing lab guide recommends at least 16 KiB.

`boardinit/Core/Src/main.c` is the practical switchboard for the firmware run.
At the time of writing, it calls `print_clock()` and
`rng_direct_stress_test_v2()`, with benchmark entry points such as
`bench_step2_audit_run()` available nearby. Enable the benchmark you want, build
and flash, then capture the UART output.

For the detailed lab protocol, hardware list, TVLA planning, and measurement
discipline, read `boardinit/LAB_GUIDE.md`.

## Verification Interpretation

Read the verification outputs by separating four kinds of evidence.

**Tool-checked with IronMask:** the generated summaries show IronMask checks for
`isw_and`, `refresh_sni`, and `linear_refresh` across selected orders and
properties. In the sample `results/1233_02072026_verification` run,
`isw_and` verifies for NI/SNI but fails PINI, `refresh_sni` verifies for
NI/SNI/PINI, and `linear_refresh` verifies for NI/PINI while SNI fails at
orders 2 and 3.

**Expected negative result:** ISW PINI failure is not a broken run. It is the
reason the project moved away from composing the construction through ISW under
PINI.

**Literature-backed:** `hpc2_and` is the multiplication used in the current
`ks_add`. Its PINI property is cited from CGLS21. The local IronMask runner may
emit `error_or_timeout` or false negative behavior for HPC2-style encodings
because IronMask does not model the complement/randomness cancellation at the
distribution level. Use SILVER or fullVerif for an independent in-house HPC2
machine check; `docs/HPC2_gate_spec.md` gives the transfer specification.

**Hand/composition arguments:** the runner emits text artifacts for
`inject_uniform`, `ks_add`, and the tree conversion status. `inject_uniform` is
a direct uniform-sharing argument. `ks_add` composes the multiplication gadget
with share-wise XOR. The tree conversion still needs the paper-side lemma/proof
argument described in `boardinit/LAB_GUIDE.md`; do not report it as fully
machine-checked by this runner.

`docs/STATUS_AND_VERIFICATION.md` references `THEOREM1_correction.md`, but that
file is not currently present in this repository. This README therefore records
the correction story directly and links only to files that are checked in.

## Troubleshooting

**Docker cannot find the image.** Pull it from GitHub Container Registry and tag
it with the local compose name:

```bash
docker pull ghcr.io/ali63yavari/m4_ubuntu_x86_host:latest
docker tag ghcr.io/ali63yavari/m4_ubuntu_x86_host:latest m4_ubuntu_x86_host:latest
```

**`/work/IronMask/src/ironmask` is missing.** The container image or mounted
`verification/` tree is incomplete. Confirm `verification/IronMask/src/ironmask`
exists inside the container, or rebuild IronMask from source inside
`/work/IronMask/src` with `make` if the image has the required dependencies.

**Verification takes a long time.** The checks are combinatorial. Start with
`--max-order 1` or `--max-order 2`, reduce `--jobs` if the host is memory
constrained, and inspect partial transcripts under `results/`.

**Result CSV shows HPC2 `error_or_timeout`.** This is not an HPC2 security
verdict. Use the HPC2 gate specification with a distribution-level checker for
an independent machine check.

**UART is silent on the M4 board.** Confirm USART2 wiring, 115200 8N1 serial
settings, common ground, and that the selected firmware entry point actually
prints. PA2 is USART2 TX on the STM32F407 target.

**RNG stalls or errors appear.** Confirm the 48 MHz RNG clock path is configured
and that the benchmark is using the direct RNG initialization. The audit output
includes RNG call and wait-cycle fields to help diagnose this.

**Tree benchmark crashes or hard-faults.** Increase stack space. The recursive
tree conversion needs substantially more stack than the sequential conversion.

## Primary References in This Repository

- `docs/STATUS_AND_VERIFICATION.md`
- `docs/HPC2_gate_spec.md`
- `boardinit/LAB_GUIDE.md`
- `verification/IronMask/Readme.md`
- `docs/m4_cycles.csv`
- `results/1233_02072026_verification/verification_summary.csv`
