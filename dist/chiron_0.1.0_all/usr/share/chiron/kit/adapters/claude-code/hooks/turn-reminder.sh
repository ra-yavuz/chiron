#!/bin/bash
# chiron UserPromptSubmit hook: injects the compressed per-turn reminder.
# Single source of truth: ../reminder.md (installed next to the hooks dir).
# No embedded copy, so the text cannot drift from the file.
# Fail-soft: any internal error exits 0 with no output.

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
reminder="$script_dir/../reminder.md"

[ -f "$reminder" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

CHIRON_REMINDER_PATH="$reminder" python3 - <<'PYEOF' 2>/dev/null || exit 0
import json, os

with open(os.environ["CHIRON_REMINDER_PATH"], encoding="utf-8") as f:
    text = f.read().strip()
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": text,
    }
}))
PYEOF
exit 0
