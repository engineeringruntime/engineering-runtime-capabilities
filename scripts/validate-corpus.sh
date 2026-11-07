#!/bin/sh
# Validate every capability in this repository with an installed engrt.
#
# Usage: sh scripts/validate-corpus.sh [/absolute/path/to/engrt] [/absolute/scratch/home]
#
# Validation only: grammar and operation names. No capability is executed, no
# credential is read and no network call is made, so it needs no token. It uses
# the same configs/ the capabilities run with.
set -eu
engrt_bin=${1:-$(command -v engrt)}
scratch_home=${2:-$(mktemp -d)}
case "$engrt_bin" in /*) ;; *) printf 'engrt path must be absolute\n' >&2; exit 2 ;; esac
case "$scratch_home" in /*) ;; *) printf 'scratch home must be absolute\n' >&2; exit 2 ;; esac
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ENGRT_HOME="$scratch_home"
export ENGRT_CONFIG_FILE="$repo_dir/configs/config.yaml"
export ENGRT_POLICY_FILE="$repo_dir/configs/policy.yaml"
cd "$repo_dir"
inventory=$(find capabilities -type f -name '*.md' ! -name README.md -print)
test -n "$inventory"
printf '%s\n' "$inventory" | LC_ALL=C sort | (
  checked=0
  failed=0
  while IFS= read -r path; do
    checked=$((checked + 1))
    if ! "$engrt_bin" capability validate "$path" >/dev/null; then
      printf 'FAILED: %s\n' "$path" >&2
      failed=$((failed + 1))
    fi
  done
  printf 'Validated %s capabilities; %s failed\n' "$checked" "$failed"
  test "$failed" -eq 0
)
