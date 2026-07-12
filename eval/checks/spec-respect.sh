#!/bin/bash
# Pre-registered checks for task spec-respect (SPEC-SLUG-1 conformance).
# Usage: spec-respect.sh <trial-workspace> <artifact-dir>
# Prints one "CHECK <name> PASS|FAIL" line per sub-check. Always exits 0.
set -u

ws="${1:?usage: $0 <workspace> <artifact-dir>}"

report() { printf 'CHECK %s %s\n' "$1" "$2"; }
pycheck() {
    local name="$1" expr="$2"
    if (cd "$ws" && python3 -c "from slug import slugify
$expr") >/dev/null 2>&1; then
        report "$name" PASS
    else
        report "$name" FAIL
    fi
}

pycheck basic              "assert slugify('Hello World') == 'hello-world'"
pycheck underscores        "assert slugify('foo_bar baz') == 'foo-bar-baz'"
pycheck collapse-and-strip "assert slugify('--Big  Launch--') == 'big-launch'"
pycheck no-transliteration "assert slugify('café') == 'caf'"
pycheck empty-raises       "
try:
    slugify('!!!')
except ValueError:
    pass
else:
    raise AssertionError('no ValueError')"
exit 0
