# R11.1 — Hammer anchor / unfix / milestone 5

Status: **OWNER_QA**

Owner task: [R11.1](../roadmap_11_1_extended_interactions_and_arrangement.md)

## Scope and decisions

- M5 reuses the existing interaction resolver and prolonged capture; no Hammer-specific input subsystem is introduced.
- `C_Anchorable` is the authored policy and runtime rest accumulator. `S_AnchorStability` is the sole writer of stable time.
- `C_PlayerAnchored` is the distinct runtime marker for objects fixed by the Player. Authored/frozen world bodies are not inferred as player-anchored.
- `AnchoredBodySnapshot` is the single reversible snapshot for body properties changed by anchoring; M5 does not spread restore state across unrelated flags.
- A Hammer is any physical hand item with `C_AnchorTool` and a normal `DEF_AnchorAction`; LMB therefore stays the existing PRIMARY tool-use path.
- Unfix is a normal target-authored `DEF_UnfixAnchorAction` on F/USE with the existing prolonged timing contract.
- Support safety is a one-shot short physics query in each dependent object's authored local support direction. Only other `C_PlayerAnchored` objects may join the recursive unfix cluster.

## Current

Implementation and automated regression validation are complete.

Live-test regressions fixed:
- PhysicalSlot no longer reparents stored items during observer dispatch; the authored slot owns a `RemoteTransform3D` driver and the item keeps its original parent.
- Carry targeting authoritatively skips/recasts through the actor's held body so CarryPlacement remains the gameplay target.
- `hammer.tscn` and `anchorable_test_box.tscn` are authored runtime fixtures and are instanced into the current `main_level.tscn` without rewriting existing scene transforms.

Validation:
- `test_physical_slots.gd`: 10/10, 62 assertions.
- `test_anchoring.gd`: 5/5, 31 assertions.
- `physical_slots_placement` smoke: PASS.
- `anchoring` smoke: PASS.
- Project structure validation: PASS.

Owner QA:
- store/take a hand item in a PhysicalSlot and confirm no scene-tree errors;
- Carry a box, aim at CarryPlacement through/around the held body, and place it;
- pick up Hammer, wait for AnchorableTestBox to settle, LMB Fix, then hold F to Unfix.

