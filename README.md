# chiron

> A mentor kit for coding agents: an operating doctrine plus mechanical enforcement hooks that make weaker models work with the discipline of stronger ones.

Named after the centaur who trained heroes. You lose access to a top-tier model; the next model down inherits its ways of working.

## Install

The easiest path: hand your agent the raw URL of the install prompt and tell it to install chiron. It clones the repo, asks you for scope, wires the hooks, runs the self-test, and reads the doctrine:

```
https://raw.githubusercontent.com/ra-yavuz/chiron/main/INSTALL-PROMPT.md
```

Or do it by hand. The kit is a plain git checkout; `bash`, `python3`, and (recommended) `git` are the only requirements:

```bash
git clone https://github.com/ra-yavuz/chiron.git
chiron/bin/chiron install --project /path/to/your/repo
chiron/bin/chiron doctor  --project /path/to/your/repo
```

Optionally put `bin/chiron` on your PATH (`ln -s "$PWD/chiron/bin/chiron" ~/.local/bin/chiron`). There is no package to install; the doctrine, hooks, and eval harness all live in this repository.

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
| Project checklist | Optional `.chiron/checklist.md` in the project root: user-owned, project-specific steps ("run shellcheck before committing") carried into every turn, read live from disk (inlined when small, pointed to when oversized). The agent edits it only on explicit request. |
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

`chiron doctor` is a real self-test: it feeds synthetic tool calls to every installed hook and asserts the expected verdicts (the guard denies a planted `--no-verify`, the stop gate blocks an unverified edit, the session hook writes its canary, the reminder hook inlines a planted checklist).

## Project checklist

The doctrine is deliberately generic; the rules that are specific to one project ("run shellcheck before committing", "never migrate the prod DB without a dry-run") live in an optional, user-owned file:

```
<project root>/.chiron/checklist.md
```

Nothing creates this file at install time. When it exists, the per-turn hook inlines its content into every prompt, read live from disk, so "add X to the checklist" takes effect on the next turn with no session restart. Its steps bind like the doctrine's non-negotiables, and consequential replies must account for them in pre-response check item 6, so the checklist cannot be silently skipped.

Ownership is one-directional by doctrine: the user (or the agent, when the user explicitly asks) edits the file; the agent never touches it on its own initiative. That makes it the durable landing place for one-off feedback: say "put that in the checklist" once and it becomes a standing rule instead of a correction you repeat every session.

Checklists larger than 6000 characters are not inlined; the reminder degrades to a read-this-file pointer so a runaway file cannot bloat every turn. The file must be a regular file resolving inside the project root: a symlink pointing outside is ignored, because a hook that inlines arbitrary external file content into every prompt would be an exfiltration channel in a hostile repo. A file that is not valid UTF-8 is reported as unreadable rather than enforced. On the Codex CLI adapter there are no hooks, so `AGENTS.md` instructs the agent to read the checklist itself instead of receiving it inlined.

For any other agent, paste `doctrine/doctrine.md` into its system prompt; expect weaker adherence than with enforcement. Which difference is exactly what the eval measures.

## Does it actually help?

Do not take the premise on faith; `eval/` is an A/B harness that measures whether the kit moves doctrine-targeted behaviors on a given model, with pre-registered mechanical checks, canary-verified treatment delivery, a positive control, and a report script that refuses directional claims the data cannot carry. Measured results, including cost overhead, live in [`RESULTS.md`](RESULTS.md). Methodology and honest limitations: [`eval/README.md`](eval/README.md).

## What else closes the gap

Rules fix behavior, not knowledge. [`TOOLING.md`](TOOLING.md) maps the remaining failure modes to mechanical tools: local RAG for grounding in your codebase, a second-model disagreement channel, task tracking, plan-then-execute.

## Uninstall

Remove the `chiron` entries from `.claude/settings.json` (a `settings.json.chiron-bak` backup is written at install time), then delete `.claude/chiron/`, and for Codex installs `AGENTS.md` plus `.chiron/`. A `.chiron/checklist.md` you wrote is your content; keep it or delete it as you see fit. Then delete the cloned repo.

## License

MIT. Author: [Ramazan Yavuz](https://ramazan-yavuz.tr).
