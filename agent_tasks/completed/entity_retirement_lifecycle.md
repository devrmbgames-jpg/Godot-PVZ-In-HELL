# Entity retirement ownership

Status: **DONE**

## Task state

### Goal

Fix the independently reproduced use-after-free in HazardLifecycle.retire without changing
GECS or mechanically removing required Node cleanup. Found during the №41 lifetime audit;
it is not a Templates/Traits regression and does not broaden №41.

### Current

Source at baseline `857ec02d7703eab840dbf496730be48d29294d99` and audit checkpoint
`1097d8421892e86c4c8a6aff9b3fa6af18069dfa` is byte-identical.
Pinned GECS remove_entity queues in-tree Nodes but immediately frees detached Nodes.
HazardLifecycle.retire then called queue_free on the already freed detached Entity.

Fix: `1e86867a7ad38a6dfcfbddd212c9d2705e88f129`.
Return after transferring destruction to World.remove_entity.
Unregistered Nodes retain caller-owned queue_free; in-tree retirement remains idempotent.
Depletion's similar code is intentionally unchanged: its availability gate rejects detached Nodes.
Ownership review collected: BASE `857ec02d7703eab840dbf496730be48d29294d99`,
TARGET `4dee2e2557b4737b279b6eb83e03183619b5e6ad`; ARCHITECTURE PASS,
HazardLifecycle destruction explicitly verified, no new lifetime finding.

### Validation

Same four regression cases on Godot 4.7.1 / GECS v8:
- Baseline: **3/4**, runtime `Cannot call method 'queue_free' on a previously freed instance`.
- Fixed current worktree: **4/4 / 9 assertions**, zero diagnostics.
- Cases: registered detached, registered in-tree/repeated retirement, unregistered retirement,
  and depletion rejection of a detached Entity.

Reproduce in an imported isolated BASE snapshot with this same checked-in test, then fixed dev:

```powershell
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path <snapshot> --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_entity_retirement.gd -gexit
```

Logs: `tests/artifacts/entity_retirement_baseline.log`, `...entity_retirement_fixed.log`.
Regression: [test_entity_retirement.gd](../../tests/gut/test_entity_retirement.gd).
Formatter, incremental agent, strict architecture and structure PASS; final native parser
**3/3**, zero diagnostics (includes the memory probe). Final native suite includes this repair:
**99 scripts / 1422/1422 / 12060 assertions**, zero diagnostics.

### Owner QA / blockers

No remaining blocker or rendered QA requirement. Fix and collected review are complete.
