---
name: agent-continuity
description: >
  Keep long Codex tasks recoverable across context limits, interruptions, model handoffs,
  and multi-session work while minimizing token usage. Use for multi-step refactors, audits,
  broad fixes, or whenever work may outlive the current context window.
---

# Agent continuity and token economy

Repository state is durable memory. Chat history is not.

## Start/resume

1. Read `CURRENT_WORK.md`.
2. If active, verify branch/head and changed files.
3. Read only context/docs referenced by the checkpoint.
4. Continue from **Next exact step**.
5. If checkpoint and repository disagree, trust repository state and repair the checkpoint.

## During work

Maintain `WORK.md` as checklist.

Update `CURRENT_WORK.md` after a meaningful milestone, before a risky broad change, and before an expected interruption.

Checkpoint only:
- goal/acceptance criteria;
- branch/base;
- changed paths;
- decisions/invariants and why;
- validation already executed;
- unresolved blocker;
- exact next path/symbol/command.

Never paste full logs, diffs, source files, or chat summaries into checkpoints.

## Token-saving search order

1. root `CONTEXT.md`;
2. nearest subsystem `CONTEXT.md`;
3. exact class/function/path search;
4. direct callers/callees;
5. broader search only if needed.

Do not repeatedly reread unchanged files.

## Execution rules

- Prefer the next verifiable change over a long plan.
- Split changes so milestones can be validated independently.
- Use deterministic scripts/formatters/tests for questions tools can answer.
- Record hypotheses as hypotheses until proven.
- If blocked, leave the tree coherent and write blocker + exact evidence needed next.
- Never save context by skipping validation.

## Large tasks

Create `agent_tasks/<name>.md` only when one short checkpoint is insufficient.
