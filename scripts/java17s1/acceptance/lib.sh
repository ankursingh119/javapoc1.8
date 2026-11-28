#!/usr/bin/env bash
# Shared helpers for card SBJ17-16's acceptance checks (docs/cards/SBJ17-16.md). Sourced, not run.
# The checks run from the repository root. They reuse SBJ17-9's helpers (fail, pass, merge_base, java_major,
# surefire_totals, require_module_green) from scripts/java17/acceptance/lib.sh, which is left unchanged.
. scripts/java17/acceptance/lib.sh

# The lines of one job in a workflow file given on stdin (the same reading as scripts/ci/acceptance/lib.sh).
job_block_of() {
  awk -v id="$1" '
    /^jobs:/ { injobs = 1; next }
    injobs && /^[^ #]/ { injobs = 0 }
    injobs && $0 ~ "^  " id ":[[:space:]]*$" { printing = 1; next }
    injobs && printing && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { printing = 0 }
    printing { print }
  '
}

# Major class-file version of one .class file: bytes 6 and 7, big-endian (52 is Java 8, 61 is Java 17).
class_major() {
  local b
  b=$(od -An -tu1 -j6 -N2 "$1" | tr -s ' ')
  set -- $b
  echo $(( $1 * 256 + $2 ))
}
