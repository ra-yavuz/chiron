#!/bin/bash
# chiron UserPromptSubmit hook: injects the compressed per-turn reminder,
# plus the project checklist (.chiron/checklist.md) when one exists.
# Single source of truth: ../reminder.md (installed next to the hooks dir).
# No embedded copy, so the text cannot drift from the file.
# The checklist is user-owned and read live from disk on every turn, so an
# edit takes effect on the very next prompt. Oversized checklists degrade
# to a read-this-file pointer so a runaway file cannot bloat every turn.
# A checklist that resolves outside the project root (symlink) is ignored:
# inlining arbitrary external file content into every prompt would be an
# exfiltration channel in a hostile repo.
# Fail-soft: any internal error exits 0 with no output, and a broken
# checklist never suppresses the base reminder.

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || exit 0
reminder="$script_dir/../reminder.md"
project_root="${CLAUDE_PROJECT_DIR:-$PWD}"

[ -f "$reminder" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

CHIRON_REMINDER_PATH="$reminder" CHIRON_PROJECT_ROOT="$project_root" \
python3 - <<'PYEOF' 2>/dev/null || exit 0
import json, os

# Inline cap in characters (roughly 1.5k tokens). Beyond it the checklist
# is pointed to instead of inlined. Read is bounded to cap + 1 so a huge
# file can neither blow the hook timeout nor memory.
CHECKLIST_INLINE_CAP = 6000

with open(os.environ["CHIRON_REMINDER_PATH"], encoding="utf-8") as f:
    text = f.read().strip()

root = os.path.realpath(os.environ.get("CHIRON_PROJECT_ROOT", "") or os.sep)
path = os.path.join(root, ".chiron", "checklist.md")

checklist = ""
oversize = False
unreadable = False
if os.path.isfile(path):
    real = os.path.realpath(path)
    if real == root or real.startswith(root + os.sep):
        try:
            with open(path, encoding="utf-8") as f:
                checklist = f.read(CHECKLIST_INLINE_CAP + 1)
        except (OSError, UnicodeDecodeError):
            unreadable = True
        else:
            oversize = len(checklist) > CHECKLIST_INLINE_CAP
            checklist = checklist.strip()

if unreadable:
    text += (
        "\n\nPROJECT CHECKLIST present at " + path + " but not readable as"
        " UTF-8 text, so it was NOT inlined. Tell the user; once the file is"
        " fixed it will be enforced again."
    )
elif oversize:
    text += (
        "\n\nPROJECT CHECKLIST present at " + path + " but too large to"
        " inline (over " + str(CHECKLIST_INLINE_CAP) + " chars). Read it now"
        " and regard every applicable step; account for them in pre-response"
        " check item 6."
    )
elif checklist:
    text += (
        "\n\nPROJECT CHECKLIST (from " + path + "; user-owned, edit it only"
        " on explicit user request). Every applicable step below binds like"
        " the non-negotiables above; account for the steps you regarded in"
        " pre-response check item 6:\n\n" + checklist
    )

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": text,
    }
}))
PYEOF
exit 0
