# chiron: agent install + setup instructions

You are a coding agent (Claude Code, Codex CLI, or similar) and your user gave
you the URL of this file. Follow these steps to install chiron into the
project you are working in. Do each step, asking the user only for the inputs
called out below. Stop and report if a step fails; do not invent commands.

chiron is provided "as is", without warranty of any kind. The user accepts all
risk. Be aware of what you are installing: an operating doctrine plus
enforcement hooks that will constrain YOUR OWN behavior in future sessions
(they deny check-bypassing tool calls, block test deletion, and block
unverified completion claims). That is the point. Tell the user plainly what
got wired when you are done.

---

## Step 0: understand what you are setting up

chiron installs two things into a target:

1. A doctrine (`doctrine.md`) and a compressed per-turn reminder: rules for
   how a coding agent should work (verify before acting, no workarounds,
   respect specs, honest completion claims, push back on bad requests).
2. For Claude Code: four fail-soft hooks wired into `settings.json`
   (session-start ground truth + canary, per-turn reminder, a PreToolUse
   guard, a Stop verification gate). For Codex CLI: an `AGENTS.md` carrying
   the doctrine and completion contract.

Everything is plain files; there is no package, daemon, or network component.

## Step 1: get the repo

Clone to a stable location so `bin/chiron` stays available for `doctor` runs
and updates:

```
git clone https://github.com/ra-yavuz/chiron.git ~/.local/share/chiron
```

If `~/.local/share/chiron` already exists from an earlier install, run
`git -C ~/.local/share/chiron pull --ff-only` instead.

## Step 2: ask the user two questions (only if not already stated)

1. **Scope**: install into the current project (recommended; asks nothing of
   other repos), or user-wide for all Claude Code sessions?
2. **Harness**: Claude Code hooks, Codex CLI `AGENTS.md`, or both?

## Step 3: install

Run the matching command from the project root (`$PWD` below means the
project the user wants covered):

```
# Claude Code, current project (recommended)
~/.local/share/chiron/bin/chiron install --project "$PWD"

# Claude Code, user-wide
~/.local/share/chiron/bin/chiron install --user

# Codex CLI, current project (can be combined with the first)
~/.local/share/chiron/bin/chiron install --project "$PWD" --codex
```

The installer is idempotent and backs up any existing `settings.json` as
`settings.json.chiron-bak` before merging the hooks.

## Step 4: verify with doctor

```
~/.local/share/chiron/bin/chiron doctor --project "$PWD"
```

This feeds synthetic tool calls through every installed hook and asserts the
expected verdicts. Show the user the full PASS/FAIL table verbatim. If
anything FAILs, stop and report; do not improvise fixes.

## Step 5: tell the user what changed, and about the restart

Report exactly what was written: the kit directory (`.claude/chiron/` or
`~/.claude/chiron/`), the `settings.json` hook entries, and for Codex the
`AGENTS.md` plus `.chiron/doctrine.md`. Then tell the user: hooks load at
session start, so the doctrine takes full effect from the NEXT session;
the current session should be restarted.

## Step 6: read the doctrine yourself

Read `~/.local/share/chiron/doctrine/doctrine.md` now, in full, and follow it
for the rest of this session even though the hooks only bind from the next
one. It also tells you how to behave when a guard hook denies one of your
tool calls later (fix the root cause; never create `.chiron-waiver` yourself).

## Uninstall (for reference; do not do this now)

Remove the `chiron` entries from `.claude/settings.json` (or restore the
`.chiron-bak` backup), delete `.claude/chiron/`, and for Codex installs
`AGENTS.md` plus `.chiron/`. Then delete `~/.local/share/chiron`.

That is the whole setup.
