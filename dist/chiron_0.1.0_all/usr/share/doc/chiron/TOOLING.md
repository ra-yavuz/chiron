# Tooling catalog: closing capability gaps mechanically

The chiron principle: enforcement beats prose. A weaker model gains more
from a tool call it cannot get wrong (or cannot make at all) than from
another paragraph of instructions. This table maps common weak-model
failure modes to tools that close them mechanically. Wiring documentation
lives in each tool's own repository; it is not duplicated here.

| Capability gap | Tool | Where |
|---|---|---|
| Hallucinating project internals (paths, symbols, config) | hydra-rag-hooks: local RAG hook + MCP server for Claude Code and Codex, grounded in the actual repo | https://github.com/ra-yavuz/hydra-rag-hooks |
| No second opinion; single-model blind spots | agent-doublethink: two agents on different models coordinate over an end-to-end encrypted channel; disagreement surfaces per turn | https://github.com/ra-yavuz/agent-doublethink |
| Broker for the above | doublethink: broker-blind E2E pub/sub | https://github.com/ra-yavuz/doublethink |
| Bypassing checks, deleting tests, force pushes | chiron guard hook (PreToolUse): denies the tool call with the doctrine reason | this repo, `adapters/claude-code/hooks/guard.sh` |
| Claiming "done" without running anything | chiron stop-verify hook (Stop): blocks the stop until a verify command ran or the gap is stated | this repo, `adapters/claude-code/hooks/stop-verify.sh` |
| Hallucinated file paths at session start | chiron session-start hook: injects the real file inventory, detected test runner, and spec locations | this repo, `adapters/claude-code/hooks/session-start.sh` |
| Attention decay over long sessions | chiron turn-reminder hook: compressed doctrine re-injected every turn | this repo, `adapters/claude-code/hooks/turn-reminder.sh` |
| Dishonest or vague completion reports | Completion contract: fixed CHANGES / TESTS-RUN / NOT-VERIFIED block, machine-checkable | `doctrine/doctrine.md`, enforced socially by the reminder and mechanically by eval checks |
| Losing track of multi-step work | The harness's built-in task tracking, or any per-project task store the agent reads at session start | harness feature; no extra install |
| Executing a misread task | Plan-then-execute: use the harness's plan mode for non-trivial work so the human approves the frame before edits happen | harness feature; no extra install |

Notes:

- Everything in the left column is a behavior, not a knowledge gap. More
  model capability shrinks these failures but does not remove them; the
  mechanical layer catches what remains.
- For agents without hook support, the doctrine text itself
  (`doctrine/doctrine.md`) is the fallback: paste it into the system
  prompt or the agent's instruction file. Expect weaker adherence than
  with enforcement; that difference is exactly what `eval/` measures.
