---
name: task-lifecycle
description: Use when creating, resuming, updating or completing durable agent_tasks/*.md work spanning sessions or milestones.
---

# Durable task lifecycle

Use for persistent task state, not for every plan, Fix or quick code change. If a user identifies an existing task, continue it rather than creating another record. A Plan Mode plan or Goal does not require a repository task file.

## Single source of truth

- Use one owning `agent_tasks/<task>.md` for its goal, acceptance, current status, latest checkpoint, next action, validation evidence and unresolved findings.
- Do not create a separate queue, CURRENT_WORK file, activity log or task-history source of truth. Git commits document implementation history; `docs/` documents product contracts; `qa_tasks/` owns remaining manual acceptance.
- Keep the file as current state, not a chronological stream. Replace stale Current/Next, old validation summaries and redundant review checkpoints. Preserve *unique* evidence via concise results and links to manifests or reproducible commands.
- Use **full Git SHAs** for base, target, review and fix checkpoints. Short hashes alone do not identify review evidence reliably.
- Aim for at most **200 lines** per active task file. Exceptions require indispensable current contracts/evidence, not migrated activity logs or repeated test runs. Do not move the same log to an auxiliary report.

## Scope control

- The declared goal and acceptance define completion. Investigate suspected regressions with comparable baseline/current observations before expanding implementation.
- An independent defect must have its own owner, reproduction, evidence and acceptance in a separate task; link it from the original when needed. A moved defect does not waive a mandatory original acceptance criterion.
- If fulfilling acceptance requires a changed decision, identify the exact owner decision and leave that criterion open. Do not silently alter scope, redefine PASS or keep inventing related work.
- Preserve statuses honestly: pending review, engine/tool blockers, missing evidence and owner gameplay/visual QA are not DONE.

## Complete and archive

When all required implementation, review/triage and verification gates pass, move the **existing** task file to `agent_tasks/completed/<original relative path>` in the same completion batch. Preserve original subdirectory layout, final status and concise evidence. Update incoming links and relative links in the moved file; do not leave a duplicate or forwarding file in the active directory.

Tasks with blockers, unfinished implementation, REVIEW_PENDING or required owner acceptance remain active under their actual status. Use [review-orchestration](../review-orchestration/SKILL.md) when a committed milestone needs formal triage; use [validation-workflow](../validation-workflow/SKILL.md) for test evidence.
