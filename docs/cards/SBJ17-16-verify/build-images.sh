#!/usr/bin/env bash
# Verify, SBJ17-16: build the old and new runner images.
set -euo pipefail
cd "$(dirname "$0")"
docker build -q --target old -t sbj1716-old .
docker build -q --target new -t sbj1716-new .
