#!/usr/bin/env bash
# AC5 README setup needs only JDK 17.
# Static: README.md asks for JDK 17 and names no other JDK for the setup (no "JDK 8", "Java 8", "Temurin 8",
# "1.8" or "JavaSE-1.8"); setup-local.cmd checks for Java 17 and no longer for 1.8; scripts/write-vscode-settings.ps1
# writes a JavaSE-17 runtime.
# Run: the README's manual build ("Manual equivalent (macOS, Linux ...)", section 3.2,
#   mvn -B -DskipTests package dependency:build-classpath -Dmdep.outputFile=target/local-classpath.txt)
# runs in a container that holds JDK 17 and no other JDK (the pipeline's runner has JDK 8, 11 and 21 installed, so it
# cannot show "only"), on a copy of HEAD (git archive), and must pass and leave Java 17 class files.
# setup-local.cmd is Windows-only and is checked statically (docs/cards/SBJ17-17.md, Test design).
set -euo pipefail
cd "$(dirname "$0")/../../.."
. scripts/java17f/acceptance/lib.sh

grep -qE 'JDK 17|Temurin 17' README.md || fail "README.md does not ask for JDK 17"
old=$(grep -nE 'JDK ?8|Java ?8|Temurin ?8|1\.8|JavaSE-1\.8|version=8' README.md || true)
if [ -n "$old" ]; then
  echo "$old" | head -20 >&2
  fail "README.md still names Java 8 for the setup ($(echo "$old" | wc -l) lines)"
fi
grep -qE '"17|17\.' setup-local.cmd || fail "setup-local.cmd does not check for Java 17"
if grep -qE '1\.8\.|JDK 8|Java 8' setup-local.cmd; then
  fail "setup-local.cmd still checks for or asks for Java 8"
fi
grep -q "JavaSE-17" scripts/write-vscode-settings.ps1 || fail "scripts/write-vscode-settings.ps1 does not write a JavaSE-17 runtime"
if grep -q "JavaSE-1.8" scripts/write-vscode-settings.ps1; then
  fail "scripts/write-vscode-settings.ps1 still writes a JavaSE-1.8 runtime"
fi
echo "README.md, setup-local.cmd and write-vscode-settings.ps1 ask for JDK 17 only"

image=${AC5_IMAGE:-maven:3.9.9-eclipse-temurin-17}
m2="${HOME}/.m2/repository"; mkdir -p "$m2"
out=target/java17f-readme; rm -rf "$out"; mkdir -p "$out"
git archive --format=tar HEAD | docker run --rm -i -v "$m2:/root/.m2/repository" "$image" bash -c '
  set -e
  echo "JDKs in this container:"
  jdks=$(ls -d /opt/java/* /usr/lib/jvm/* 2>/dev/null || true); echo "$jdks"
  n=$(echo "$jdks" | grep -c . || true)
  [ "$n" -eq 1 ] || { echo "FAIL: the container holds $n JDKs, not one" >&2; exit 3; }
  java -version 2>&1 | grep -q "version \"17" || { echo "FAIL: the container java is not 17" >&2; exit 3; }
  mkdir /work && cd /work && tar -x
  mvn -B -q -DskipTests package dependency:build-classpath -Dmdep.outputFile=target/local-classpath.txt
  for m in common spark-job workflow-app; do
    f=$(find $m/target/classes -name "*.class" | head -1)
    [ -n "$f" ] || { echo "FAIL: $m built no class files" >&2; exit 4; }
    major=$(od -An -tu1 -j6 -N2 "$f" | awk "{print \$1 * 256 + \$2}")
    echo "$m: $f major $major"
    [ "$major" = 61 ] || { echo "FAIL: $m class files are major $major, not 61" >&2; exit 4; }
  done
  [ -s target/local-classpath.txt ] || [ -s spark-job/target/local-classpath.txt ] || { echo "FAIL: no local-classpath.txt" >&2; exit 4; }
' > "$out/build.log" 2>&1 || { tail -40 "$out/build.log" >&2; fail "the README's manual build does not pass with only JDK 17 installed (log $out/build.log)"; }
grep -E '^(JDKs|/opt|/usr|common|spark-job|workflow-app):?' "$out/build.log" || true
pass "AC5 the README asks for JDK 17 only, and its manual build passes in a container holding JDK 17 alone"
