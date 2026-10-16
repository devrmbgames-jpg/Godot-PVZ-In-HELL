---
name: task-lifecycle
description: Use when creating, resuming, updating or completing durable .agents/tasks/*.md work spanning sessions or milestones, including autonomous backlog execution.
---

# Durable task lifecycle

Use one existing owning task for interruptible/multi-session work. A small Fix, session
plan or Plan Mode does not require a repository task. Current project safety remains in AGENTS.md.

## Single source of truth

The owning task holds goal/acceptance, current status, decisions, one next action,
actual validation and unresolved findings. A parent owns overall status; child cards
own only stage details. No separate queue/current-work file/activity/completion log.
Replace obsolete state/evidence rather than appending action history. Keep unique proof
via concise results, full 40-character base/target/review/fix SHAs and artifact references.
Aim at <=200 lines and <=12 KiB of working state; preserve indispensable requirements,
not long log lines disguised as a short document.

For owner-requested non-destructive refactors, immutable source snapshots may preserve
original requirements/history. They are NOT another live task/status source. Read only
the relevant requirement sections; never replay their historical Current/Next. See
[task README](../../tasks/README.md) and its source manifest for precedence and routing.
Do not append new reports/logs to frozen sources or keep copying them forward.

## Autonomous backlog execution

For an owner request to implement the whole backlog, use the selection/continuation
loop in [task README](../../tasks/README.md). Read root headers, then the current package;
exclude completed/references and route children through their parent.
A finished work package is a checkpoint, not a request for another permission to continue.
Proceed to the next permitted package/task while work remains runnable. Preserve exact
resume state before context/session interruption; do not promise a daemon or self-restart.

Separate technical completion from required owner acceptance. OWNER_QA or unavailable
review blocks only affected gates; continue independent work without false DONE/PASS.
Dependencies name a specific verified provider contract, not a cycle of full-task DONEs.
Do not implement a second owner just because the provider task is not globally closed.
A broad execution request supersedes old planning-only creation text, not explicit owner
DEFERRED/fallback decisions, rendered-QA restrictions or Git/destructive permissions.
Missing authoring data permits labelled reversible prototypes, not invented final canon.

## Scope control

Goal and full acceptance remain binding, including preserved source requirements.
One coherent behavior package includes its required lifetime/persistence checks;
do not split a single transaction into unchecked partial layers or reopen accepted
packages merely to match a new plan. Compare baseline/current evidence for new defects.
Independent defects need their own owner/reproduction/evidence/acceptance and link;
this does not waive an original mandatory acceptance criterion.
If a changed product decision is required, keep its exact criterion open. Do not quietly
redefine PASS, accept unapproved balance or invent adjacent work to prolong the task.
Record a concrete blocker and next independent task instead of idle waiting/retry loops.

## Complete and archive

Use [validation-workflow](../validation-workflow/SKILL.md) and
[review-orchestration](../review-orchestration/SKILL.md) for actual gates.
Review pending/unavailable, required engine checks NOT_RUN and open owner acceptance
are not DONE. At most two targeted repair cycles per checkpoint; preserve unresolved
findings and continue only independent scopes when blocked.

Only after full required implementation, validation, review/triage and owner acceptance
(or explicit owner deferral of specified manual scope), set DONE and move the EXISTING
file to .agents/tasks/completed/<original-relative-path> in the same completion batch.
Preserve evidence/layout; fix incoming links and relative source/QA links. No active
copy or forwarding stub. Lasting product contracts belong in docs/; manual checklists
may live in .qa/tasks/ but do not themselves waive the owning task's acceptance.
