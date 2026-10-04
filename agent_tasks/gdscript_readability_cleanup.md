# Task — GDScript readability cleanup
Status: **IN_PROGRESS**

## Task state

### Goal

Improve readability of existing project-owned GDScript by separating distinct logical phases inside functions and removing dense uninterrupted code blocks.

This is a readability/formatting pass only. Runtime behavior must remain unchanged.

## Scope

- Review project-owned `.gd` files.
- Exclude third-party/vendor code under `addons/` unless the project explicitly owns the file.
- Prioritize functions that contain several conceptual phases but are written as one continuous block.
- Apply the rules from `AGENTS.md` and `docs/code_style.md`.

## Required cleanup

- Add a single blank line between genuinely separate logical phases where it improves scanning.
- Typical boundaries: setup/input, guard clauses, lookup/collection, state mutation, external side effects, and return/follow-up work.
- Keep tightly related statements together.
- Preserve existing regions and useful comments.
- Do not add blank lines mechanically after every statement.
- Do not perform unrelated refactoring while touching a file.

## Hard constraints

- No behavior changes.
- No control-flow changes.
- No expression/evaluation-order changes.
- No API, signal, exported-field, node-path, resource-path, scene-contract, or persistence-schema changes.
- No renames unless required to fix an actual parser/style violation already covered by project rules.
- Do not edit `addons/` as part of this task.

## Execution

Work in coherent batches rather than one file at a time:

1. Find a bounded group of dense project-owned scripts.
2. Apply readability-only spacing changes.
3. Review the diff to ensure it is formatting/readability only.
4. Parser-validate changed GDScript near the end of the batch.
5. Continue with the next batch.

Avoid GUT/runtime tests unless a change accidentally goes beyond formatting and needs behavioral verification.

## Acceptance

- Dense multi-phase functions are visually separated into readable logical blocks.
- Closely related statements remain grouped.
- No mechanical over-spacing.
- `git diff --check` is clean.
- Changed project-owned GDScript parses without new/relevant warnings or errors.
- Diff review confirms no intended behavior change.

### Current

Completed batches: NPC/customer/dialogue/AI (27 changed scripts), remaining runtime services (102 reviewed, 93 changed). Input guards, subsequent lookup/action phases and failure cleanup are separated; consecutive related guards remain together. Next: engine glue, UI/debug and scheduled behavior, then significant test/tool scripts. Addons remain excluded. R25 documentation follows this formatting pass.

### Validation

Exact nonblank-line comparison and comment/string-aware executable-source comparison PASS via utils/verify_gdscript_nonbehavior_changes.py --mode spacing. Godot fresh-process parser: 27/27 (.bin/readability-npc-customer-parser.log), 93/93 (.bin/readability-services-parser.log), zero failures and no script warnings/errors. The second runner's initial absolute-path manifest was corrected before acceptance. Diff review retains clustered guards; whitespace PASS. No gameplay/GUT/export reruns were performed for formatting-only edits.

### Owner QA / blockers

None expected; this task should not require gameplay QA if it remains formatting-only.
