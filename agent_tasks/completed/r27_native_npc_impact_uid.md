# R27 validation — native NPC impact Trait UID

Status: **DONE**

Owner: native resource identity; discovered while validating
[R27.2](../r27_npc_passing_and_spacing.md).

## Task state

### Goal / acceptance

Restore the existing `uid://cxi2q17pyr72l` expected by `district_npc.tscn:14`
on `content/domains/combat/authoring/et_impact_capture.tres`, preserving its
Trait ID, component recipe and all scene paths. Native compilation and the
focused social-rule suite must complete without this invalid-UID warning.

### Current / evidence

The resource header has no UID at both
`7e67e938e154c071203c5efcd27c8b539c66aa4b` and
`5c1028cf43b39f40f19aec47aa1442686a87944e`; the scene still references it.
This is a pre-existing fixture/resource defect, independent of RV-001/RV-002.
Godot 4.7.1 fresh-import evidence: strict parser wrapper rejects the warning;
`test_npc_rules.gd` reports 8/9 tests and 63/64 assertions because inherited
`test_two_deaths_start_delayed_one_per_morning_resettlement` receives it twice.
Repair restores only the missing header UID. Offline one-line resource repair;
no live editor, third-party edits, new UID, tuning or gameplay changes.

### Validation / review

Fix: `82c5c617d793b6985b15256a8915332f50b14b4d`.
Independent source review against
`ead2a026cb512f9a5e2a6445c10f6ca647ae6cfe`: architecture/style PASS,
no findings; reviewer does not execute runtime checks.
After normal headless editor rescan, main ran Godot4.7.1:

- PASS `utils/parse_gdscript.gd` on S_NpcIntent and test_npc_traffic:2/0 failures,exit0.
- PASS focused `test_npc_rules.gd`:9/9 tests,63 assertions,exit0.
- No UID warning remains in either final log.

### Owner QA / blockers

No scene or recipe semantics changed. No remaining blocker in this resource identity task.
Owner gameplay QA remains open in R27.2.
