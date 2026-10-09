---
name: review-orchestration
description: Use for substantial committed PVZ Feature/Refactoring checkpoints or explicit parallel review and finding triage. Coordinates immutable Git snapshots, a concurrent read-only reviewer and bounded fixes.
---

# Parallel review pilot — Main + one read-only Reviewer

An **agent workflow**, not a background daemon or a second manager agent.
Follow existing GECS and GDScript style contracts. Main is the sole writer.

## Commit-bound review

1. After a coherent committed checkpoint, resolve exact full `BASE_SHA`
   (previous reviewed baseline) and `TARGET_SHA` (checkpoint). Do not hand
   the reviewer a moving HEAD, mutable worktree, or untracked source.
2. Spawn **one** configured `reviewer` with both SHAs, owning task goal and
   limited touched paths. It must read `git diff BASE_SHA TARGET_SHA` and
   `git show TARGET_SHA:path` rather than changing or reading live files.
   No test runs, editor/MCP access, Git checkout or task editing by reviewer.
3. **Continue independent work without immediately waiting**, only if new
   work cannot depend on the unreviewed architecture and will not compete for
   Godot/editor state. At most one child agent may run; do not spawn validator
   concurrently. If no independent work exists, collect the review now.
4. At integration boundary and always before DONE, collect the result. A
   pending/unavailable review is `REVIEW_PENDING`/`NOT_RUN`, not PASS.
   If host cannot run a parallel reviewer, fall back to serial review and
   state that fact. If self-reviewed, label `NON_INDEPENDENT`.

## Triage (Main Agent owns decisions)

- Reviewer reports only provisional R1, R2... findings with source SHA,
  severity, path/symbol, reproducible evidence and minimal fix suggestion.
- Main checks each candidate against original snapshot and **current** HEAD;
  deduplicates by `path + symbol + violated contract`, then accepts or
  rejects based on evidence. Assign canonical RV-001.. within an existing
  durable `agent_tasks/<owner>.md`, **not** a global queue. For one-session
  tasks keep the decisions in the conversation.
- Allowed final statuses: `FIXED(fix SHA, test)`, `REJECTED(evidence)`,
  `OBSOLETE(current SHA)`, `DEFERRED(owner/task/reason)`.
  `ACCEPTED` is temporary until resolved; `REVIEW_PENDING` blocks DONE.
- **P0:** data loss/security/authority → stop affected work immediately.
  **P1:** behavioral/GECS/lifecycle blocker → fix before dependent changes.
  **P2:** changed-scope architecture/style → fix before milestone DONE.
  **P3:** optional cleanup → bundle or explicitly defer. No fake PASS.

## Bounded fix cycle

Main implements scoped fixes and runs focused parser/GUT/static validators.
Validator can run *after* reviewer, never as a second concurrent child.
Re-review only the original finding and its fix diff, not the entire repo.
Maximum **two targeted repair/re-review cycles per checkpoint**; if still
failing, mark BLOCKED and surface evidence rather than looping forever.
A new meaningful defect may need its own clearly scoped task, not reset
the same issue's repair counter.

## Review-efficiency experiment

Compare 2–3 representative checkpoints: total elapsed time, review overlap
with independent work, available tokens, accepted/false/stale findings and
repair iterations. Missing telemetry => NOT_MEASURED. Avoid live Codex evals,
new background watchers and GitHub CI dependencies. Details/prompt examples:
`docs/parallel_review_workflow.md` and `docs/ai_prompt_cheatsheet.md`.
