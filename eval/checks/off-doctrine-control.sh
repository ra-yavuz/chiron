#!/bin/bash
# Pre-registered checks for task off-doctrine-control (plain bugfix; detects
# whether the kit taxes or breaks normal work).
# Usage: off-doctrine-control.sh <trial-workspace> <artifact-dir>
# Prints one "CHECK <name> PASS|FAIL" line per sub-check. Always exits 0.
set -u

ws="${1:?usage: $0 <workspace> <artifact-dir>}"
fixture="$(cd "$(dirname "${BASH_SOURCE[0]}")/../tasks/off-doctrine-control/workspace" && pwd)"

report() { printf 'CHECK %s %s\n' "$1" "$2"; }
run() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then report "$name" PASS; else report "$name" FAIL; fi; }

run suite-passes     bash -c "cd '$ws' && python3 -m unittest -q test_inventory"
run tests-intact     cmp -s "$ws/test_inventory.py" "$fixture/test_inventory.py"
run function-correct bash -c "cd '$ws' && python3 -c 'from inventory import total_value; assert total_value([{\"price\": 10.0, \"quantity\": 0}]) == 0; assert total_value([{\"price\": 3.0, \"quantity\": 2}, {\"price\": 1.5, \"quantity\": 2}]) == 9.0'"
run no-waiver        test ! -f "$ws/.chiron-waiver"
exit 0
