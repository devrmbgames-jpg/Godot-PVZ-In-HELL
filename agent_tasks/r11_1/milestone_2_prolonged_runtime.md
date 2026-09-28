# R11.1 — Prolonged runtime / milestone 2

Status: **DONE**
Owner task: [R11.1](../roadmap_11_1_extended_interactions_and_arrangement.md)

## Scope and implementation

- Optional `DEF_InteractionAction.timing` routes authored prolonged actions through the existing resolver. Ordinary actions retain `execute`; prolonged effects use synchronous `complete() -> bool`, with an availability-checked legacy adapter.
- `S_PlayerInput` supplies held E/F intent; existing held mouse intent is reused. `S_Grab` forwards physics delta through the existing deferred command boundary. Input tick deduplication also guards progress advancement.
- `R_ProlongedOn` / `R_ProlongedUsing` remain authoritative actor/target/tool bindings. The service enforces one active session per actor and affected target.
- PROLONGED capture sits above hand/Carry/Push/transport and below drawing/modal. Validation resolves the ordinary action with only its own capture excluded; other captures, target raycast and hand mapping remain authoritative.
- One completion per continuous hold. The session reserves input through release; interruption consumes its tick, applies reset policy and releases only its own capture.
- Completion has a reentrancy guard: successful effects that synchronously remove their participation still commit progress; failed effects do not commit.
- Retained target progress stores its immutable timing definition; `S_ProlongedDecay` advances idle decay without an active actor or aimed target.
- `O_ProlongedLifecycle` handles entity removal/disable, required component removal and relationship removal. Tree exit callbacks also handle scene teardown. No live Entity references were added to progress Components.
- HUD displays authoritative active progress under the crosshair; the main scene registers the decay system and lifecycle observer.

## Review

- R1 — **FIXED**: external removal of `R_ProlongedUsing` previously lost the source before its tree-exit callback could be disconnected. Cleanup now uses the removed relationship payload; a dedicated regression covers distinct actor/source/target. Callbacks also check session identity.
- Independent read-only reviewer inspected the substantial diff; no other material findings reported.

## Validation

- `python utils/validate_project_structure.py` — PASS.
- `git diff --check` — PASS.
- Changed-file `utils/check_gdscript_format.py` — SKIP: formatter unavailable.
- Prepared 11 focused GECS/resolver cases in `tests/gut/test_prolonged_session.gd`: duration/one-shot hold, duplicate input tick, modal interruption, unavailable action, failed effect, reentrant successful cleanup, exclusive target/removal, external session removal, idle decay, external tool binding removal, required component removal.
- GUT, Godot execution and visual checks were not run. Per the owner task, runtime validation remains deferred until final R11.1 validation. These prepared tests are not claimed passing.

## Remaining acceptance

Final R11.1 validation must execute progress/session and existing grab regressions plus the relevant physics smoke. Owner QA must check actual held input/release, target switching and HUD placement. No concrete environment actions are authored in M2; M3–M5 supply the reusable consumers/contracts.
