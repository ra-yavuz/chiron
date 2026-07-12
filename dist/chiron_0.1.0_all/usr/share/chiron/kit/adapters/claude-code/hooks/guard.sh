#!/bin/bash
# chiron PreToolUse hook (matcher: Bash|Edit|Write).
# Blocks mechanical workaround patterns the doctrine forbids: --no-verify,
# error swallowing with || true, force pushes, deleting or weakening tests.
# A blocked call returns the doctrine reason to the model, which cannot
# drift past a denied tool call.
# Waiver: a .chiron-waiver file in the project root (created only on the
# user's explicit instruction, with a reason inside) allows the operation
# but surfaces a warning. The file is visible and auditable.
# Fail-soft: any internal error exits 0 with no output (tool call proceeds).

set -u

tmp="$(mktemp 2>/dev/null)" || exit 0
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" 2>/dev/null || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

CHIRON_HOOK_INPUT="$tmp" CHIRON_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}" \
python3 - <<'PYEOF' 2>/dev/null || exit 0
import json, os, re, sys

with open(os.environ["CHIRON_HOOK_INPUT"], encoding="utf-8") as f:
    data = json.load(f)

tool = data.get("tool_name", "")
tin = data.get("tool_input", {}) or {}
root = os.environ.get("CHIRON_ROOT", ".")

TEST_PATH = re.compile(
    r"(^|/)(tests?|spec|__tests__)/|test_[^/]*\.py$|_test\.(go|py|rb)$"
    r"|\.test\.[jt]sx?$|\.spec\.[jt]sx?$"
)
SKIP_MARKERS = re.compile(
    r"pytest\.mark\.skip|unittest\.skip|@unittest\.expectedFailure|@Ignore\b"
    r"|t\.Skip\(|it\.skip|test\.skip|describe\.skip|xit\(|xdescribe\(|xtest\("
)
ASSERTION = re.compile(r"\bassert\b|expect\(|require\.|assert_|assertEquals|t\.Errorf")

def verdict(reason):
    waiver = os.path.join(root, ".chiron-waiver")
    if os.path.isfile(waiver):
        try:
            with open(waiver, encoding="utf-8") as f:
                wtext = f.read().strip()[:200]
        except OSError:
            wtext = "(unreadable)"
        print(json.dumps({
            "systemMessage": (
                "chiron guard: operation allowed only because .chiron-waiver "
                "exists (" + wtext + "). Remove the waiver when done."
            )
        }))
        sys.exit(0)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                "chiron doctrine violation: " + reason
                + " Doctrine rule 1: no workarounds, no skipped or deleted "
                  "tests; find the root cause and fix it. If the user has "
                  "explicitly ordered this exact operation, ask the user to "
                  "create a .chiron-waiver file in the project root stating "
                  "the reason; do not create it yourself."
            ),
        }
    }))
    sys.exit(0)

if tool == "Bash":
    cmd = tin.get("command", "") or ""
    if re.search(r"--no-verify\b|--skip-checks\b", cmd):
        verdict("command uses --no-verify or --skip-checks to bypass checks.")
    if re.search(r"\|\|\s*true\b", cmd):
        verdict("command swallows a failure with '|| true' instead of fixing it.")
    if re.search(r"\bgit\s+push\b[^|;&]*(\s--force(-with-lease)?\b|\s-f\b)", cmd):
        verdict("force push rewrites shared history.")
    for m in re.finditer(r"(?:^|[;&|]\s*)(?:git\s+)?rm\s+([^;&|]*)", cmd):
        for arg in m.group(1).split():
            if not arg.startswith("-") and TEST_PATH.search(arg):
                verdict("command deletes a test or spec file (" + arg + ").")

elif tool in ("Edit", "Write"):
    path = tin.get("file_path", "") or ""
    if TEST_PATH.search(path):
        if tool == "Write":
            content = tin.get("content", "") or ""
            if SKIP_MARKERS.search(content):
                verdict("writing a skip marker into test file " + path + ".")
        else:
            old = tin.get("old_string", "") or ""
            new = tin.get("new_string", "") or ""
            if SKIP_MARKERS.search(new) and not SKIP_MARKERS.search(old):
                verdict("edit adds a skip marker to test file " + path + ".")
            if new.strip() == "" and ASSERTION.search(old):
                verdict("edit deletes assertions from test file " + path + ".")

sys.exit(0)
PYEOF
exit 0
