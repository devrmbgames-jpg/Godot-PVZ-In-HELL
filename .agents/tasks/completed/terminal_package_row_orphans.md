# Terminal package row — orphan Node lifetime

Status: **DONE**
BASE_SHA: `6843e23e94c1ffb8f8d4784660f6783f09f67e22`
TARGET_SHA: `14c2294cfb1f35c71d3c03711c21479270e2d42e`

## Task state

### Goal / acceptance

- Identify whether terminal open/close or the isolated fixture retains package-row Nodes.
- Fix the evidenced owner so its ended lifecycle leaves no owned orphan Nodes.
- Keep package selection/detail behavior and authored row layout intact.
- Verify the relevant native terminal lifecycle; distinguish live Nodes from shutdown-only retention.

### Current / evidence

Independent finding while verifying [Creepy M2](../creepy_npc_unpredictable_stalking.md).
The real terminal-reader case in `tests/gut/test_npc_stalking.gd` reports **46 Orphans**,
including a `PanelContainer` with `ui_terminal_package_line.gd` and45 descendants.
The same count exists before M2: `.artifacts/godot_agent/gut-20261016-073531451.stdout.log`;
M2 observation: `.artifacts/godot_agent/gut-20261016-080613272.stdout.log`.
The product queues its detached designer row correctly. The fixture ended in that same frame,
before the deletion queue ran. Its teardown now awaits one process frame after freeing its root.
Product runtime and authored layout are unchanged; the owner's mouse-filter edits remain unstaged.

A native headless probe repeated real terminal create/register/open/close/remove55 times in one
process. After5 warmup cycles, all50 settled orphan samples were0; all55 detached rows were queued
and every captured WeakRef was null after two frames. This proves no surviving row in that measured
lifecycle, without asserting general gameplay memory acceptance.

### Validation

- Native GUT27/27,245 assertions PASS, no orphan report, stderr empty:
  `.artifacts/godot_agent/gut-20261016-083822816.{stdout,stderr}.log`.
- Native ParseFiles1/0 PASS: `parsefiles-20261016-083852835.{stdout,stderr}.log`.
- Lifecycle probe exit0/stderr empty:
  `.artifacts/godot_agent/terminal_row_lifetime_probe.{stdout,stderr}.log`.
- MCP1 checked/empty/scripts_instantiated0; incremental formatter1 PASS; diff whitespace PASS.
- Immutable BASE/TARGET above reviewed: no material findings; architecture/style PASS, reviewer execution NOT_RUN. Main triage: nothing accepted/outstanding, repair0/2. No engine-warning exemption was used.

### Owner QA / blockers

No owner decision is currently required; headless native lifecycle investigation is authorized.
Rendered QA is NOT_RUN and unnecessary for establishing Node ownership.

### Completion

All declared fixture lifecycle gates and independent review/triage are complete.
The measured product lifecycle had no surviving row; only premature fixture measurement required
correction. No runtime/UI edit or owner gameplay/visual acceptance is required for this scope.
