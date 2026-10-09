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

Do not maintain a separate queue index, current-work file, or completed-task history log. If supporting milestone files exist, the root task remains the only owner of overall status/current/next.

Task files are current snapshots, not action journals. Replace obsolete Current/Next and validation
when a checkpoint advances; retain only relevant evidence, open findings and durable decisions.
Do not list every test run/experiment or copy implementation history already available in Git.
Aim for at most 200 lines; justify indispensable current detail if exceeding that recommendation.
Use concise links to manifests/reproductions rather than a second report containing the same log.
Independent defects belong to separate tasks; an existing acceptance gate remains open until fixed
or explicitly changed by the owner. This README is the canonical task state and
archiving contract; skills link here instead of duplicating its rules.

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

## Completion and archive

When the required implementation, validation and review are complete, set the task to DONE and move its existing file to `agent_tasks/completed/<original relative path>` in the same completion batch. For example, `agent_tasks/refactoring_v2/<task>.md` becomes `agent_tasks/completed/refactoring_v2/<task>.md`.

Preserve the task's completion status and evidence, keep its original subdirectory structure, and update both incoming links and relative links inside the archived file. Keep one authoritative file; do not leave an active copy or forwarding stub. The completed directory stores the original task records, without a separate completion log or queue.

Unfinished implementation, pending review and unresolved acceptance keep a task active under its actual status. Lasting product contracts belong in `docs/`; separate remaining manual scenarios belong in `qa_tasks/`.
