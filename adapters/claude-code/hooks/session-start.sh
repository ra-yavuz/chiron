#!/bin/bash
# chiron SessionStart hook.
# 1. Tells the model to read the full doctrine once.
# 2. Injects ground truth about the project (file inventory, test runner,
#    spec locations) so weak models do not hallucinate paths.
# 3. Writes a canary file proving the kit actually fired (used by
#    `chiron doctor` and by the eval harness).
# Fail-soft: any internal error exits 0 with no output.

set -u

root="${CLAUDE_PROJECT_DIR:-$PWD}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || script_dir=""
doctrine="$script_dir/../doctrine.md"

# Canary: timestamped proof that the chiron session hook executed.
printf 'chiron session-start fired: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$root/.chiron-canary" 2>/dev/null || true

command -v python3 >/dev/null 2>&1 || exit 0

inventory=""
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    total=$(git -C "$root" ls-files 2>/dev/null | wc -l)
    dirs=$(git -C "$root" ls-files 2>/dev/null | awk -F/ 'NF>1 {print $1"/"} NF==1 {print "(root)"}' | sort | uniq -c | sort -rn | head -12)
    files=$(git -C "$root" ls-files 2>/dev/null | head -40)
    inventory="Tracked files: $total. Top-level layout (count dir):
$dirs
First files:
$files"
else
    files=$(find "$root" -maxdepth 2 -type f -not -path '*/.git/*' 2>/dev/null | head -40)
    inventory="Not a git repository. Files (depth 2, first 40):
$files"
fi

runner="none detected"
if [ -f "$root/Makefile" ] && grep -qE '^(test|check):' "$root/Makefile" 2>/dev/null; then
    runner="make test (Makefile target found)"
elif [ -f "$root/package.json" ] && grep -q '"test"' "$root/package.json" 2>/dev/null; then
    runner="npm test (package.json script found)"
elif [ -f "$root/pytest.ini" ] || [ -f "$root/tox.ini" ] || { [ -f "$root/pyproject.toml" ] && grep -q pytest "$root/pyproject.toml" 2>/dev/null; }; then
    runner="pytest"
elif [ -f "$root/go.mod" ]; then
    runner="go test ./..."
elif [ -f "$root/Cargo.toml" ]; then
    runner="cargo test"
elif ls "$root"/tests/*.py "$root"/test_*.py >/dev/null 2>&1; then
    runner="pytest (test files present)"
fi

specs=""
for d in spec specs docs legal req runbooks; do
    [ -d "$root/$d" ] && specs="$specs $d/"
done
[ -n "$specs" ] || specs=" none found"

export CHIRON_DOCTRINE_PATH="$doctrine"
export CHIRON_INVENTORY="$inventory"
export CHIRON_RUNNER="$runner"
export CHIRON_SPECS="$specs"

python3 - <<'PYEOF' 2>/dev/null || exit 0
import json, os

doctrine = os.environ.get("CHIRON_DOCTRINE_PATH", "")
context = (
    "SESSION-START INSTRUCTION (chiron): read the operating doctrine now, in full: "
    + doctrine
    + " . It binds this session. Per-turn reminders refer back to it.\n\n"
    + "GROUND TRUTH (verified by the harness, do not re-derive):\n"
    + "Detected test/verify command: " + os.environ.get("CHIRON_RUNNER", "") + "\n"
    + "Spec/doc directories present:" + os.environ.get("CHIRON_SPECS", "") + "\n"
    + os.environ.get("CHIRON_INVENTORY", "")
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
PYEOF
exit 0
