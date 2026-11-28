#!/usr/bin/env bash
# AC4 Earlier cards' checks run on Java 17.
# Static, on .github/workflows/ci.yml and the scripts (SBJ17-Q28 item 2: checks that asserted Java 8 are replaced by
# their Java 17 equivalent, so the guard is kept):
# - the pipeline has one job (AC1 checks it is Java 17 alone) and every lasting check of earlier cards
#   (LASTING_CHECKS in lib.sh) exists and runs in it on every build: its step is not gated on a branch name;
# - no lasting check still asserts Java 8: a running java of 8, class-file major 52, java.specification.version
#   1.8, a JDK 8 home, or a job named jdk8.
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17f/acceptance/lib.sh

[ -f "$WORKFLOW" ] || fail "$WORKFLOW is missing"
ids=$(job_ids)
n=$(printf '%s\n' "$ids" | grep -c . || true)
[ "$n" -eq 1 ] || fail "the pipeline has $n jobs ($(echo $ids)), so the earlier checks do not all run in one Java 17 job"
job=$(printf '%s\n' "$ids" | head -1)
block=$(job_block_of "$job" < "$WORKFLOW")

missing=0
for s in "${LASTING_CHECKS[@]}"; do
  if [ ! -f "$s" ]; then
    echo "  $s: no such file" >&2; missing=$((missing + 1)); continue
  fi
  # The step's lines: from the "- " that opens it to the line that runs the check.
  step=$(echo "$block" | awk -v s="$s" '
    /^      - / { buf = "" }
    { buf = buf $0 "\n" }
    index($0, s) { printf "%s", buf; found = 1; exit }
    END { if (!found) exit 1 }
  ') || { echo "  $s: not run in job $job" >&2; missing=$((missing + 1)); continue; }
  if echo "$step" | grep -qE 'ref_name|head_ref'; then
    echo "  $s: runs only on one branch" >&2; missing=$((missing + 1))
  fi
done
[ "$missing" -eq 0 ] || fail "$missing of ${#LASTING_CHECKS[@]} lasting checks do not run in job $job on every build"
echo "all ${#LASTING_CHECKS[@]} lasting checks run in job $job on every build"

java8=0
for s in "${LASTING_CHECKS[@]}"; do
  hits=$(grep -nE '\(java_major\)" = 8|!= 52|value="1\\?\.8"|JAVA8_HOME|JAVA_HOME_8|job_block jdk8|AC2_JOB:-jdk8' "$s" || true)
  if [ -n "$hits" ]; then
    echo "$hits" | sed "s|^|  $s:|" >&2
    java8=$((java8 + 1))
  fi
done
[ "$java8" -eq 0 ] || fail "$java8 lasting checks still assert Java 8"
pass "AC4 every earlier card's lasting check (${#LASTING_CHECKS[@]}) runs in the one Java 17 job, none asserting Java 8"
