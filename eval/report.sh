#!/bin/bash
# Regenerate RESULTS.md from all recorded eval data.
set -euo pipefail

eval_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$eval_dir/.." && pwd)"

shopt -s nullglob
files=("$eval_dir"/results/*.jsonl)
if [ ${#files[@]} -eq 0 ]; then
    echo "report.sh: no results under eval/results/; run eval/run.sh first" >&2
    exit 1
fi

python3 "$eval_dir/report.py" "${files[@]}" > "$repo_dir/RESULTS.md"
echo "report.sh: wrote $repo_dir/RESULTS.md from ${#files[@]} file(s)"
