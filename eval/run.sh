#!/bin/bash
# chiron A/B eval runner.
#
# Runs each task fixture through headless Claude Code in two arms with
# IDENTICAL invocations except for the treatment:
#   vanilla  no kit
#   kit      --settings <staged hooks> --append-system-prompt-file <doctrine>
# Both arms run with a scratch CLAUDE_CONFIG_DIR (seeded only with
# credentials and an onboarding marker), --strict-mcp-config, a fresh
# fixture copy, and interleaved arm order. Results append to a JSONL file;
# already-recorded (task, arm, trial) tuples are skipped, so the runner is
# resumable.
#
# Validity: the kit's session-start hook writes .chiron-canary into the
# workspace. A kit trial without the canary, or a vanilla trial with one,
# is recorded as outcome=invalid and excluded from scoring.
set -euo pipefail

usage() {
    cat <<'HELP_EOF'
usage: run.sh --model <alias-or-id> [options]

  --model M      model to evaluate (e.g. haiku, opus). Required.
  --trials N     trials per task per arm (default 1)
  --tasks "..."  space-separated task subset (default: all under eval/tasks)
  --arms "..."   arms to run (default: "vanilla kit")
  --timeout S    per-trial timeout in seconds (default 900)
  --results F    results JSONL path (default eval/results/<model>.jsonl)

DISCLAIMER: runs a coding agent unattended with permissions bypassed in
scratch directories, and consumes paid model usage. Provided AS IS,
WITHOUT WARRANTY OF ANY KIND; you accept all risk and all costs.
HELP_EOF
}

eval_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$eval_dir/.." && pwd)"

MODEL="" TRIALS=1 TASKS="" ARMS="vanilla kit" TIMEOUT=900 RESULTS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --model)   MODEL="${2:?}"; shift 2 ;;
        --trials)  TRIALS="${2:?}"; shift 2 ;;
        --tasks)   TASKS="${2:?}"; shift 2 ;;
        --arms)    ARMS="${2:?}"; shift 2 ;;
        --timeout) TIMEOUT="${2:?}"; shift 2 ;;
        --results) RESULTS="${2:?}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "run.sh: unknown option $1" >&2; usage; exit 1 ;;
    esac
done
[ -n "$MODEL" ] || { usage; exit 1; }
[ -n "$TASKS" ] || TASKS="$(cd "$eval_dir/tasks" && printf '%s ' */ | tr -d '/')"
[ -n "$RESULTS" ] || RESULTS="$eval_dir/results/$MODEL.jsonl"

command -v claude >/dev/null 2>&1 || { echo "run.sh: claude CLI not found" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "run.sh: python3 required" >&2; exit 1; }

mkdir -p "$(dirname "$RESULTS")"
artifacts_base="$eval_dir/results/artifacts/$MODEL"
mkdir -p "$artifacts_base"

claude_version="$(claude --version 2>/dev/null | head -1 || echo unknown)"

run_tmp="$(mktemp -d)"
trap 'rm -rf "$run_tmp"' EXIT

# Stage the kit once: hooks resolve ../doctrine.md relative to themselves.
stage="$run_tmp/kitstage/chiron"
mkdir -p "$stage/hooks"
install -m 0644 "$repo_dir/doctrine/doctrine.md" "$stage/doctrine.md"
install -m 0644 "$repo_dir/doctrine/reminder.md" "$stage/reminder.md"
install -m 0755 "$repo_dir"/adapters/claude-code/hooks/*.sh "$stage/hooks/"

kit_settings="$run_tmp/kit-settings.json"
CHIRON_FRAGMENT="$repo_dir/adapters/claude-code/settings-fragment.json" \
CHIRON_STAGE="$stage" CHIRON_OUT="$kit_settings" python3 <<'PYEOF'
import json, os
with open(os.environ["CHIRON_FRAGMENT"], encoding="utf-8") as f:
    fragment = json.load(f)
text = json.dumps(fragment)
text = text.replace("$CLAUDE_PROJECT_DIR/.claude/chiron", os.environ["CHIRON_STAGE"])
with open(os.environ["CHIRON_OUT"], "w", encoding="utf-8") as f:
    f.write(text)
PYEOF

already_done() { # already_done <task> <arm> <trial>
    [ -f "$RESULTS" ] || return 1
    CHIRON_RESULTS="$RESULTS" CHIRON_KEY="$1|$2|$3" python3 <<'PYEOF'
import json, os, sys
task, arm, trial = os.environ["CHIRON_KEY"].split("|")
with open(os.environ["CHIRON_RESULTS"], encoding="utf-8") as f:
    for line in f:
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if (e.get("task"), e.get("arm"), str(e.get("trial"))) == (task, arm, trial):
            sys.exit(0)
sys.exit(1)
PYEOF
}

seed_config() { # seed_config <dir>: credentials + onboarding marker only
    mkdir -p "$1"
    if [ -f "$HOME/.claude/.credentials.json" ]; then
        install -m 0600 "$HOME/.claude/.credentials.json" "$1/.credentials.json"
    fi
    printf '{"hasCompletedOnboarding": true}\n' > "$1/.claude.json"
}

run_trial() { # run_trial <task> <arm> <trial>
    local task="$1" arm="$2" trial="$3"
    local fixture="$eval_dir/tasks/$task"
    local work="$run_tmp/w-$task-$arm-$trial"
    local cfg="$run_tmp/c-$task-$arm-$trial"
    local artifact="$artifacts_base/$task-$arm-$trial"

    rm -rf "$work" "$cfg" "$artifact"
    mkdir -p "$artifact"
    cp -r "$fixture/workspace" "$work"
    (cd "$work" && git init -q && git add -A && \
        git -c user.email=eval@localhost -c user.name=eval commit -qm fixture)
    seed_config "$cfg"

    local -a cmd
    cmd=(claude -p "$(cat "$fixture/prompt.md")" --model "$MODEL"
         --output-format json --strict-mcp-config)
    if [ "$arm" = "kit" ]; then
        cmd+=(--settings "$kit_settings" --append-system-prompt-file "$stage/doctrine.md")
    fi

    local started ended exit_code outcome
    started=$(date +%s)
    set +e
    (cd "$work" && CLAUDE_CONFIG_DIR="$cfg" timeout "$TIMEOUT" \
        "${cmd[@]}" </dev/null >"$artifact/out.json" 2>"$artifact/err.log")
    exit_code=$?
    set -e
    ended=$(date +%s)

    if [ "$exit_code" -eq 124 ]; then outcome=timeout
    elif [ "$exit_code" -ne 0 ]; then outcome=error
    else outcome=completed; fi

    # Extract the final message text for prose-shape checks.
    : > "$artifact/result.txt"
    if [ "$outcome" = "completed" ]; then
        CHIRON_OUT_JSON="$artifact/out.json" python3 - >"$artifact/result.txt" 2>/dev/null <<'PYEOF' || true
import json, os
with open(os.environ["CHIRON_OUT_JSON"], encoding="utf-8") as f:
    print(json.load(f).get("result", ""))
PYEOF
    fi

    local canary=false
    [ -f "$work/.chiron-canary" ] && canary=true
    if [ "$arm" = "kit" ] && [ "$canary" = "false" ] && [ "$outcome" = "completed" ]; then
        outcome=invalid
    fi
    if [ "$arm" = "vanilla" ] && [ "$canary" = "true" ]; then
        outcome=invalid
    fi

    local checks=""
    if [ "$outcome" = "completed" ]; then
        checks="$(bash "$eval_dir/checks/$task.sh" "$work" "$artifact" 2>/dev/null || true)"
    fi
    printf '%s\n' "$checks" > "$artifact/checks.txt"

    CHIRON_ROW_TASK="$task" CHIRON_ROW_ARM="$arm" CHIRON_ROW_TRIAL="$trial" \
    CHIRON_ROW_MODEL="$MODEL" CHIRON_ROW_OUTCOME="$outcome" \
    CHIRON_ROW_EXIT="$exit_code" CHIRON_ROW_SECS="$((ended - started))" \
    CHIRON_ROW_CANARY="$canary" CHIRON_ROW_CHECKS="$checks" \
    CHIRON_ROW_OUT_JSON="$artifact/out.json" CHIRON_ROW_CLI="$claude_version" \
    python3 >>"$RESULTS" <<'PYEOF'
import json, os, time
env = os.environ
row = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "task": env["CHIRON_ROW_TASK"],
    "arm": env["CHIRON_ROW_ARM"],
    "trial": int(env["CHIRON_ROW_TRIAL"]),
    "model_requested": env["CHIRON_ROW_MODEL"],
    "cli_version": env["CHIRON_ROW_CLI"],
    "outcome": env["CHIRON_ROW_OUTCOME"],
    "exit_code": int(env["CHIRON_ROW_EXIT"]),
    "duration_s": int(env["CHIRON_ROW_SECS"]),
    "canary": env["CHIRON_ROW_CANARY"] == "true",
}
try:
    with open(env["CHIRON_ROW_OUT_JSON"], encoding="utf-8") as f:
        out = json.load(f)
    row["session_id"] = out.get("session_id")
    row["total_cost_usd"] = out.get("total_cost_usd")
    row["models_used"] = sorted((out.get("modelUsage") or {}).keys())
    usage = out.get("usage") or {}
    row["output_tokens"] = usage.get("output_tokens")
    row["input_tokens"] = usage.get("input_tokens")
except (OSError, ValueError):
    pass
checks = {}
for line in env["CHIRON_ROW_CHECKS"].splitlines():
    parts = line.split()
    if len(parts) == 3 and parts[0] == "CHECK":
        checks[parts[1]] = parts[2] == "PASS"
row["checks"] = checks
row["score"] = (sum(checks.values()) / len(checks)) if checks else None
print(json.dumps(row))
PYEOF

    # Preserve the post-trial workspace for audit.
    mv "$work" "$artifact/workspace"
    rm -rf "$cfg"
    printf 'run.sh: %s %s trial %s: %s (checks: %s)\n' \
        "$task" "$arm" "$trial" "$outcome" \
        "$(printf '%s' "$checks" | grep -c ' PASS$' || true)/$(printf '%s' "$checks" | grep -c '^CHECK ' || true)"
}

echo "run.sh: model=$MODEL trials=$TRIALS tasks=[$TASKS] arms=[$ARMS]"
echo "run.sh: results -> $RESULTS"

for trial in $(seq 1 "$TRIALS"); do
    # Interleave arm order per trial to avoid time-of-day bias.
    if [ $((trial % 2)) -eq 1 ]; then ordered_arms="$ARMS"
    else ordered_arms="$(printf '%s\n' "$ARMS" | awk '{for(i=NF;i>0;i--) printf "%s ", $i}')"; fi
    for task in $TASKS; do
        [ -d "$eval_dir/tasks/$task" ] || { echo "run.sh: no such task: $task" >&2; exit 1; }
        for arm in $ordered_arms; do
            if already_done "$task" "$arm" "$trial"; then
                echo "run.sh: skip $task $arm trial $trial (already recorded)"
                continue
            fi
            run_trial "$task" "$arm" "$trial"
        done
    done
done
echo "run.sh: finished"
