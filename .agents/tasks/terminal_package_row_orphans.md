# Terminal package row — orphan Node lifetime

Status: **PLANNED**

## Task state

### Goal / acceptance

- Identify whether terminal open/close or the isolated fixture retains package-row Nodes.
- Fix the evidenced owner so its ended lifecycle leaves no owned orphan Nodes.
- Keep package selection/detail behavior and authored row layout intact.
- Verify the relevant native terminal lifecycle; distinguish live Nodes from shutdown-only retention.

### Current / evidence

Independent finding while verifying [Creepy M2](creepy_npc_unpredictable_stalking.md).
The real terminal-reader case in `tests/gut/test_npc_stalking.gd` reports **46 Orphans**,
including a `PanelContainer` with `ui_terminal_package_line.gd` and45 descendants.
The same count exists before M2: `.artifacts/godot_agent/gut-20261016-073531451.stdout.log`;
M2 observation: `.artifacts/godot_agent/gut-20261016-080613272.stdout.log`.
No terminal runtime/layout edits were made by M2. Product-vs-fixture ownership and repeated
runtime growth are **NOT_YET_PROVEN**. This Node observation is not covered by the owner's
shutdown-only GDScript/Resource/RID limitation.

### Validation

Only existing native GUT orphan reports were compared. Focused settled lifecycle checks,
product-vs-fixture diagnosis and independent review are NOT_RUN.

### Owner QA / blockers

No owner decision is currently required; headless native lifecycle investigation is authorized.
Rendered QA is NOT_RUN and unnecessary for establishing Node ownership.

### Next

Read the row/terminal creation and teardown owners, reproduce a focused headless lifecycle,
then fix the proven owner and commit/review separately. Preserve the owner's unrelated
`content/ui/ui_terminal_package_line.tscn` mouse-filter changes.
