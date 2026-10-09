# Retained NPC participation

NPCs keep the same registered physical-root Entity in both modes. ACTIVE derives from
STREET placement and living state; HOME, OUTSIDE and DEAD are DORMANT. Camera visibility
does not choose participation. Bodies, Components, durable inventory ownership and stable
identity remain allocated and available to unfiltered population/save queries.

| Field or effect | Authority / writer |
| --- | --- |
| Planned day, phase, required goal, phase completion | District roster, committed by `O_DistrictLifecycle` |
| Placement and accepted participation transition | `DistrictPopulationService.set_placement` |
| Historical death day | Existing confirmed death outcome via `mark_dead`; `C_Death` remains live death authority |
| Entity enabled state | GECS World, requested only through the placement owner in ordinary NPC lifecycle |
| Physical transform and velocity | Godot body; explicit `place_at` synchronization only at existing preparation/arrival/restore boundaries |
| Freeze, visibility, collision and inherited child process mode | Native `E_DistrictNpc.set_participating` adapter, called by the placement owner |
| Native BT activity | `NpcBrainService.set_participating` adapter; reset teardown explicitly aborts before reconstruction |
| Captured decision generation, transition incarnation/reason | Existing `C_NpcDecision`, explicit placement/reset operations |
| Runtime sensing/decision cadence | Existing capped `S_NpcCadence`; no dormant decision catchup |
| Hold, combat, dialogue, slot and Smart Object sessions | Existing Relationship owners; explicit cleanup and World unavailable notifications |

`set_placement` is synchronous and returns whether the request committed. Repeating the
same placement does not increment generations, reset movement or replay role cleanup.
Restore requests native reconciliation through this same operation after resetting the
derived brain; it does not have a second body/enabled writer. The persistence transaction
may temporarily enable retained Entities while rebuilding Components/links with reactions
suspended; the placement owner makes the final NPC participation decision.

The operation invalidates captured AI steps before publishing World enable/disable signals.
Nested opposite transitions inside those signals are rejected because GECS finishes its
native signal wiring after emitting them. Component/World replacement and removal are
revalidated at that callback boundary. Confirmed death during activation falls back to the
existing death owner. Transient schedule actions cancel through their existing operation;
durable inventory links remain untouched.

GECS already disables dormant root callbacks. The native adapter additionally disables
inherited child processing while retaining authored process mode for reactivation. This
suspends hidden animation work without changing clips or introducing another animation
state machine. Body freeze and zero collision still own physical dormancy; LimboAI and
avoidance remain disabled. Placed actors retain their authored editable scene representation.

Task45A measured fixture: 12 retained bodies, 5 ACTIVE. Before the change, 5 root callbacks
and 12 child animation mixers were eligible to process. After the change, 5 roots and 5
animation mixers are eligible; 7 dormant mixers stop. This measures work eligibility,
not wall-clock frame time, memory savings or shipping FPS. Body allocation is retained.
Evidence: `tests/artifacts/refactoring_v2_45_baseline.log` and task45 focused fixtures.

Task45B–C still own safe activation failure/session acceptance, same-mode persistence and
the completed milestone performance report. No offscreen travel/economy/combat is introduced.
