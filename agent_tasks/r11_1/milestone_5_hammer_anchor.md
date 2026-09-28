# R11.1 — Hammer anchor / unfix / milestone 5

Status: **IN_PROGRESS**

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

Core data/service/action/system contracts are being implemented. Next: wire stability into the Interaction system group, add focused GUT + real-physics support smoke, review and run final R11.1 validation.
