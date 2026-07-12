# chiron eval: does the kit actually move behavior?

An A/B harness that measures whether installing the chiron kit changes
doctrine-targeted behaviors on a given model, and what it costs. It is
deliberately narrow: it does not claim to make a weaker model equal a
stronger one, and its report script refuses directional claims the data
cannot carry.

## Design

Two arms, identical invocations, headless Claude Code (`claude -p`):

- **vanilla**: scratch `CLAUDE_CONFIG_DIR` (seeded only with credentials
  and an onboarding marker), `--strict-mcp-config`, fresh fixture copy.
- **kit**: exactly the same, plus `--settings <staged chiron hooks>` and
  `--append-system-prompt-file <doctrine.md>`.

No `--bare` anywhere: stripping the harness only in one arm would rig the
comparison. Arm order is interleaved per trial. Every trial records model,
CLI version, session id, cost, tokens, duration, and outcome
(completed / timeout / error / invalid) to a JSONL file; the runner
resumes by skipping recorded trials.

Validity mechanics:

- The kit's session-start hook writes `.chiron-canary` into the
  workspace. Kit trial without canary, or vanilla trial with one, is
  recorded as `invalid` and excluded from scoring: silent treatment
  failure cannot masquerade as "the kit does nothing".
- The `positive-control` task succeeds only via output the doctrine
  trivially forces. If it does not separate the arms, `report.py` voids
  every claim for that model.

## Tasks

| task | probes | trap |
|---|---|---|
| trap-workaround | root-cause discipline | a comment suggests deleting the failing test |
| spec-respect | spec discovery and conformance | spec/SPEC.md contains non-obvious contractual rules |
| hallucination-bait | verify-before-acting | the requested tar flag does not exist |
| positive-control | treatment delivery | none; plumbing gate |
| off-doctrine-control | normal work unharmed | none; measures the doctrine tax |

Checks are mechanical only (file hashes, functional assertions, contract
files like DECISION.txt), pre-registered by committing them before the
first scored run, and live outside the fixtures so a model cannot read or
edit its own grader. Scoring is the fraction of sub-checks passed.

## Running

```bash
# cheap plumbing validation + primary A/B
eval/run.sh --model haiku --trials 5

# small directional batch on a bigger model
eval/run.sh --model opus --trials 2 --timeout 1500

# regenerate RESULTS.md from everything recorded
eval/report.sh
```

## Honest limitations

- Tasks and checks were written by the doctrine's author; models can be
  scored only on behaviors someone thought to test. Genre overfitting is
  real.
- Single-prompt runs measure doctrine content, not long-session
  attention decay, which is what the per-turn hook exists for.
- Small N gives wide confidence intervals; `report.py` prints "not enough
  data to say" rather than a direction when the pooled CI includes zero.
- A machine-wide managed-settings hook (if present on the host) fires in
  both arms symmetrically; it is not removed, only equalized.

DISCLAIMER: the harness runs a coding agent unattended with permissions
bypassed inside scratch directories and consumes paid model usage.
Provided AS IS, WITHOUT WARRANTY OF ANY KIND; you accept all risk and
all costs.
