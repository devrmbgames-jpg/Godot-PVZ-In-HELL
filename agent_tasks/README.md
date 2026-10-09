# Durable agent tasks

This directory is only for implementation state that must survive the current Codex/VS Code session.

## When to create a file

Create or reuse `agent_tasks/<task>.md` when at least one is true:
- the work is genuinely long/interruptible and is expected to continue in another session/thread;
- several future sessions need durable decisions/milestones;
- the user explicitly asks for repository-tracked task state.

Do **not** create a task file for a local Fix, a normal single-session Task, or merely because Plan Mode was used. Session Plan + Goal are the normal execution state.

## Ownership

A durable task file is the single repository source for its own:
- goal and constraints;
- optional milestones;
- durable decisions;
- exact checkpoint / next action;
- validation actually performed;
- remaining blockers or owner QA.

Do not maintain a separate queue index, current-work file, or completed-task history. If supporting milestone files exist, the root task remains the only owner of overall status/current/next.

For a substantive reviewed milestone, accepted findings belong to the **same existing task** under `## Review findings`; only Main assigns RV-001 and updates status. Keep SHA, priority, evidence, fix owner, verification and final disposition. No new global `REVIEW_QUEUE.md`. If the task is single-session and has no durable task file, keep triage in the session. See `docs/parallel_review_workflow.md`.

Suggested compact header:

```md
# Rxx — Task name
Status: **PLANNED | IN_PROGRESS | DEFERRED | BLOCKED | OWNER_QA**

## Goal
...

## Constraints / acceptance
...

## Current
...

## Validation
...

## Owner QA / blockers
...
```

When implementation no longer needs durable state, remove the task file after preserving any lasting product contract in `docs/` and any remaining manual checks in `qa_tasks/`. Git keeps the historical implementation record.
