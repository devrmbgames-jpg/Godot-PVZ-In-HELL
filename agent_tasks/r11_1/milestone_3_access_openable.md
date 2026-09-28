# R11.1 — Access and openable contracts / milestone 3

Status: **DONE**

Owner task: [R11.1](../roadmap_11_1_extended_interactions_and_arrangement.md)

## Implementation and decisions

- `DEF_AccessRequirement` requires a stable item ID and/or all specified tags on the same concrete item. `C_AccessItem` carries this identity. Null/empty non-consuming requirements allow access; an empty consuming requirement is invalid.
- `ItemAccessService.evaluate` returns explicit `AccessResult.Outcome`; `fulfill` re-evaluates at execution. No stored grant becomes a second authority.
- `DEF_ItemAccessProvider` is the stateless extension point for physical storage and future inventory. Optional actor `C_ItemAccess.providers` overrides sources; default `DEF_HeldItemAccess` searches both hands and Carry using existing relationship-validated queries. Providers must revalidate ownership on consumption, failing without side effects when refused.
- `consume_item` defaults false. The held provider releases and removes exactly one matching concrete Entity when explicitly requested; no stack/inventory implementation is introduced.
- `C_Openable` owns locked/unlocked state, desired open/closed endpoint and physics-confirmed `actual_fraction`. Unlock and open are separate operations. Access denial makes the unlock action unavailable rather than displaying a successful prompt.
- `DEF_OpenableAction` provides separate OPEN/CLOSE/UNLOCK actions through the existing resolver/action set. Author unique `action_id`, E/INTERACT slot and captions (`Открыть`, `Закрыть`, `Отпереть`) per entry. Optional prolonged timing uses the existing boolean completion contract.
- `DEF_OpenableMotion` provides local authored transforms and duration for both rotation and translation. `OpenableService.proposed_fraction` only proposes bounded motion; `report_fraction` accepts actual physics progress. A blocked physical controller leaves the actual fraction unchanged. No body transforms are written by this milestone.
- R13 must apply movement with collision validation and migrate concrete Door/Drawer scenes to this contract. Existing `C_Door`/door scene scaffolding is preserved; do not attach two independent lock authorities when migrating.

## Review and validation

- Self-review covered denied access, stale ownership, multiple hands, failed consumption, separate unlock/open transitions and physics authority. No open material findings.
- Focused headless GUT invocation for `test_openable_access.gd`, `test_prolonged_progress.gd`, `test_prolonged_session.gd`: prolonged suites passed 18/18; three M3 tests initially failed because the fixture retained the authored component rather than the live GECS copy.
- Corrected fixture and added provider-refusal regression. Re-ran only `test_openable_access.gd`: **9/9 PASS, 44 assertions**, exit 0. Previous prolonged suites were not repeated.
- `python utils/validate_project_structure.py` and `git diff --cached --check` — PASS. Optional formatter unavailable.
- Headless editor import registered new script classes without parse errors. It reported sandbox-denied editor settings writes and certificate-store diagnostics; the first combined GUT process also reported resource leaks on exit despite passing all prolonged cases. The isolated M3 GUT run exited cleanly apart from the environment certificate diagnostic. These are not claimed clean whole-project runs.
- Logs: `tests/artifacts/r11_1_gut_console.log`, `tests/artifacts/r11_1_m3_gut_console.log` (ignored artifacts).
- No smoke or visual run: this milestone adds contracts rather than concrete physics movement. Complex obstruction/hinge and gameplay scenarios belong to later integration/owner QA.
