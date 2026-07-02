#!/bin/bash

# usage: ./evaluate.sh --max-order 8

TIMESTAMP=$(date +"%H%M_%d%m%Y")

# Combine the timestamp into your final string
OUT_DIR="${TIMESTAMP}_verification"
echo $OUT_DIR

# python3 /work/run_step3_ironmask_pini.py \
#   --ironmask /work/IronMask/src/ironmask \
#   --gadgets-c /work/gadgets/gadgets.c \
#   --out-dir /work/results/$OUT_DIR \
#   --max-order 5 \
#   --jobs 4 \
#   --timeout 36000 \
#   --include-pini \
#   "$@"

python3 /work/run_step3_ironmask_hpc2_og.py \
  --ironmask /work/IronMask/src/ironmask \
  --gadgets-c /work/gadgets/gadgets.c \
  --out-dir /work/results/$OUT_DIR \
  --max-order 3 \
  --jobs 4 \
  --timeout 840000 \
  --include-pini \
  --include-hpc2 \
  "$@"
