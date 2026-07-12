#!/bin/bash
# chiron Stop hook: mechanical "no unverified completion" enforcement.
# If the session edited code files but never ran anything that looks like a
# test or verification command, the stop is blocked once with a reason fed
# back to the model. The stop_hook_active flag guarantees no loop: the
# second stop always passes.
# Documentation-only changes (.md, .rst, .txt, docs/) are exempt.
# Fail-soft: any internal error exits 0 (stop proceeds).

set -u

tmp="$(mktemp 2>/dev/null)" || exit 0
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" 2>/dev/null || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

CHIRON_HOOK_INPUT="$tmp" python3 - <<'PYEOF' 2>/dev/null || exit 0
import json, os, re, sys

with open(os.environ["CHIRON_HOOK_INPUT"], encoding="utf-8") as f:
    data = json.load(f)

if data.get("stop_hook_active"):
    sys.exit(0)

transcript = data.get("transcript_path", "")
if not transcript or not os.path.isfile(transcript):
    sys.exit(0)

DOC_ONLY = re.compile(r"\.(md|rst|txt)$|(^|/)docs/")
VERIFY_CMD = re.compile(
    r"\b(pytest|go test|cargo test|npm test|yarn test|bun test|make test"
    r"|make check|tox\b|ctest|rspec|phpunit|mvn test|gradle test"
    r"|python3? -m (pytest|unittest)|node --test|shellcheck|ruff\b"
    r"|bash -n\b|dpkg-deb\b|go vet|cargo check|npm run (test|lint|check))"
)

edited = []
verified = False
with open(transcript, encoding="utf-8", errors="replace") as f:
    for line in f:
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        msg = entry.get("message") or {}
        content = msg.get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            name = block.get("name", "")
            tin = block.get("input", {}) or {}
            if name in ("Edit", "Write", "NotebookEdit"):
                p = tin.get("file_path", "") or tin.get("notebook_path", "")
                if p:
                    edited.append(p)
            elif name == "Bash":
                if VERIFY_CMD.search(tin.get("command", "") or ""):
                    verified = True

code_edits = [p for p in edited if not DOC_ONLY.search(p)]
if code_edits and not verified:
    shown = ", ".join(sorted(set(code_edits))[:8])
    print(json.dumps({
        "decision": "block",
        "reason": (
            "chiron doctrine rule 8: code files were modified (" + shown + ") "
            "but no test or verification command was run this session. Run "
            "the project's test/verify command now and report the actual "
            "outcome in the completion contract. If no runnable verification "
            "exists for this change, state that explicitly under NOT-VERIFIED "
            "and finish."
        ),
    }))
sys.exit(0)
PYEOF
exit 0
