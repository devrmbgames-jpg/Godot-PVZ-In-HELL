---
name: validation-workflow
description: Use when verifying code/scene changes or closing implementation milestones; selects parser, formatter, validators, GUT and smoke checks.
---

# Scoped change validation

Choose the cheapest check capable of falsifying the changed behavior, then run a broader acceptance surface only at an appropriate milestone. Run checks after a coherent edit batch, not after every tiny patch. Do not trade correctness for fewer tool calls.

Docs/prompt/config-only edits need relevant text/link/schema checks, not gameplay/GUT runs. Non-visual headless Godot and local disposable tests are allowed when relevant; gameplay/rendered/visual QA needs explicit owner approval.

## GDScript

- Before a coherent commit of project-owned `.gd`, run `python utils/check_gdscript_format.py --changed`. The wrapper checks changed lines and new files without mass-rewriting legacy source. Missing GDQuest `gdscript-formatter` returns exit 2 = **NOT_RUN**, not PASS.
- When checking an already committed milestone, use `--base <revision>`; use `--strict` only when the declared Phase 3/full-file migration requires it.
- Validate changed project-owned `.gd` with the Godot parser near the end of the batch; resolve newly introduced parse **and relevant reload warnings**. Prefer Godot AI MCP `script_patch`/`script_create` diagnostics when editor access exists. `filesystem_manage(scan)` alone does not prove parser cleanliness. Without MCP, use available headless Godot/static checks and say what could not run.

## Structure, integration and regressions

- For substantial code/scene edits run `python utils/validate_agent_changes.py`, `python -B utils/validate_architecture.py --strict` and `python utils/validate_project_structure.py`; use structure-specific checks when their contracts change.
- `validate_agent_changes.py --staged` checks the Git index. `--report-only` is **not** an accepted PASS. Static validators supplement, not replace, architecture review.
- For a completed large gameplay milestone, normally run one relevant focused GUT surface and one relevant headless smoke/runtime check, unless the task has a more specific acceptance contract. Use [gut-testing](../gut-testing/SKILL.md) for authoring/execution. Avoid running all tests after each edit.
- Review substantive committed checkpoints against immutable SHAs via [review-orchestration](../review-orchestration/SKILL.md), triage findings and resolve accepted P0/P1/P2 before DONE.

## Evidence and exceptions

- Report command/check, relevant scope and PASS, FAIL or NOT_RUN. Never report a check as passed merely because an edit or filesystem write succeeded. Keep console output compact; preserve failure details and relevant logs.
- A project should not be declared verified if required parser/runtime checks were unavailable; report the blocker or unverified surface honestly. Never claim headless validation proves visual/gameplay feel.
- Shutdown retention is not automatically a gameplay leak. If a task genuinely involves memory growth, orphan Objects/Resources or shutdown diagnostics, read [memory/lifetime diagnostics](references/memory-lifetime.md). Do not load that reference for routine code verification.
