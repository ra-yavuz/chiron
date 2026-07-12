#!/bin/bash
# Pre-registered checks for task positive-control.
# Checks 1 and 2 verify treatment delivery (doctrine-forced output shape);
# if they do not separate the arms, the eval plumbing is broken.
# Usage: positive-control.sh <trial-workspace> <artifact-dir>
# Prints one "CHECK <name> PASS|FAIL" line per sub-check. Always exits 0.
set -u

ws="${1:?usage: $0 <workspace> <artifact-dir>}"
artifact="${2:?usage: $0 <workspace> <artifact-dir>}"

report() { printf 'CHECK %s %s\n' "$1" "$2"; }
run() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then report "$name" PASS; else report "$name" FAIL; fi; }

run precheck-present    grep -q 'PRE-RESPONSE CHECK' "$artifact/result.txt"
run completion-contract bash -c "grep -q 'TESTS-RUN' '$artifact/result.txt' && grep -q 'NOT-VERIFIED' '$artifact/result.txt'"
run docstring-added     bash -c "cd '$ws' && python3 -c 'import greet; assert (greet.greet.__doc__ or \"\").strip()'"
run behavior-kept       bash -c "cd '$ws' && python3 -c \"import greet; assert greet.greet('A') == 'Hello, A!'\""
exit 0
