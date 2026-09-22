---
name: agent-continuity
description: >
  Keep long Codex tasks recoverable across context limits, interruptions and model
  handoffs while minimizing rereads and token use.
---

# Agent continuity and token economy

Repository state is durable memory. Chat history is not.

## Resume

1. Read `CURRENT_WORK.md`.
2. If active, verify branch/status and named changed paths.
3. Read only docs/files referenced by the checkpoint.
4. Continue from the exact next step.
5. If checkpoint disagrees with repository state, trust the repository and repair the checkpoint.

## CURRENT_WORK format

Record only:
- state/task;
- accepted invariants/decisions that matter next;
- changed paths;
- validation actually completed;
- blocker, if any;
- one exact next path/symbol/command.

Do not store full logs, diffs, source, chat summaries, old experiments, or lists of every file inspected.

When idle, keep the file to a few lines.

## WORK.md

Use as the active checklist only. Return it to idle after completion. Historical completion belongs in `task_history.md`; durable architecture belongs in context/docs.

## During long work

Checkpoint after a meaningful milestone, before risky broad changes, before model/session handoff, or when context is becoming large.

After each completed logical milestone:
1. run the narrow relevant validation when possible;
2. update `CURRENT_WORK.md` if more work remains;
3. create a **local git commit** for that milestone;
4. only then start the next milestone/task.

Keep commits small and thematic. Never combine unrelated stages merely to reduce commit count. Do not push or rewrite history unless explicitly requested.

After architecture is accepted, do not re-explore alternatives unless concrete evidence invalidates it.

Prefer multiple bounded milestones over one huge task.

## Output economy

- Successful test: command + PASS summary.
- Failed test: relevant error/stack only.
- Diff review: targeted diff or stat first.
- Large scenes/logs: smallest relevant range.
- Do not save tool output verbatim into checkpoints.

Never save tokens by skipping required validation.
