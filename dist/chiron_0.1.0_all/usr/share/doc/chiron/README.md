# chiron

> A mentor kit for coding agents: an operating doctrine plus mechanical enforcement hooks that make weaker models work with the discipline of stronger ones.

Named after the centaur who trained heroes. You lose access to a top-tier model; the next model down inherits its ways of working.

## Quick install (Debian / Ubuntu)

```bash
sudo bash -c 'set -e; install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://ra-yavuz.github.io/apt/pubkey.gpg -o /etc/apt/keyrings/ra-yavuz.gpg && echo "deb [signed-by=/etc/apt/keyrings/ra-yavuz.gpg] https://ra-yavuz.github.io/apt stable main" > /etc/apt/sources.list.d/ra-yavuz.list && apt update && apt install -y chiron'
```

One line. Sets up the signed `ra-yavuz` apt repo if not already added, refreshes the package index, and installs chiron. Idempotent, safe to re-run.

No Debian? Clone the repo and run `bin/chiron` directly, or grab the `.deb` from [Releases](https://github.com/ra-yavuz/chiron/releases).

> **Disclaimer / no warranty**
>
> This software modifies agent-harness configuration files and injects instructions into model sessions. It is provided **as is, without warranty of any kind**, express or implied, including but not limited to merchantability, fitness for a particular purpose, and noninfringement. By installing or running it you accept that **you alone are responsible** for reviewing what it installs and for anything a configured agent does on your systems, and that the author and contributors are **not liable** for any damage, data loss, cost, or other harm arising from its use. If you do not accept these terms, do not install or run this software. Full legal terms: [`LICENSE`](LICENSE) (MIT).

## The idea

Coding agents on weaker models fail in predictable ways: they patch symptoms instead of causes, invent flags and file paths, delete the failing test, claim "done" without running anything, and agree with a bad request instead of pushing back. Prose instructions reduce this a little; models ritualize checklists and drift past them.

chiron's bet is that **enforcement beats prose**. The kit pairs a written doctrine with hooks that act mechanically:

| Layer | Mechanism |
|---|---|
| Doctrine | `doctrine/doctrine.md`: verify before acting, no workarounds, respect specs, honest completion claims, push back when the request is wrong. Loaded once per session. |
| Per-turn reminder | Compressed non-negotiables re-injected every turn (`doctrine/reminder.md`). |
| Ground truth | The session-start hook injects the real file inventory, detected test runner, and spec locations, so paths do not get hallucinated. |
| Guard | A PreToolUse hook denies `--no-verify`, `\|\| true` error swallowing, force pushes, and test deletion or weakening, with the doctrine reason fed back to the model. |
| Stop gate | A Stop hook blocks "finished" when code changed but nothing was verified, once, with instructions. |
| Completion contract | Every finished work item must end with a fixed `COMPLETION` block: CHANGES / TESTS-RUN / NOT-VERIFIED. Machine-checkable honesty. |

All hooks are fail-soft: a kit bug never blocks the agent, it just stops enforcing.

## Usage

```bash
# wire the kit into one project (Claude Code)
chiron install --project /path/to/repo

# or into every session for your user
chiron install --user

# Codex CLI: write AGENTS.md + .chiron/doctrine.md into a project
chiron install --project /path/to/repo --codex

# verify an install end-to-end (files, wiring, live hook behavior)
chiron doctor --project /path/to/repo
```

`chiron doctor` is a real self-test: it feeds synthetic tool calls to every installed hook and asserts the expected verdicts (the guard denies a planted `--no-verify`, the stop gate blocks an unverified edit, the session hook writes its canary).

For any other agent, paste `doctrine/doctrine.md` into its system prompt; expect weaker adherence than with enforcement. Which difference is exactly what the eval measures.

## Does it actually help?

Do not take the premise on faith; `eval/` is an A/B harness that measures whether the kit moves doctrine-targeted behaviors on a given model, with pre-registered mechanical checks, canary-verified treatment delivery, a positive control, and a report script that refuses directional claims the data cannot carry. Measured results, including cost overhead, live in [`RESULTS.md`](RESULTS.md). Methodology and honest limitations: [`eval/README.md`](eval/README.md).

## What else closes the gap

Rules fix behavior, not knowledge. [`TOOLING.md`](TOOLING.md) maps the remaining failure modes to mechanical tools: local RAG for grounding in your codebase, a second-model disagreement channel, task tracking, plan-then-execute.

## Uninstall

Remove the `chiron` entries from `.claude/settings.json` (a `settings.json.chiron-bak` backup is written at install time), then delete `.claude/chiron/`, and for Codex installs `AGENTS.md` plus `.chiron/`. Package removal: `sudo apt remove chiron`.

## License

MIT. Author: [Ramazan Yavuz](https://ramazan-yavuz.tr).
