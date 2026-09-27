# R22.5 M1 — System Decomposition

## Goal

Remove structural coupling and pseudo-System/service patterns while preserving behavior. Verify every historical issue against current `master` before editing.

## Current disposition targets

| Area | Target |
| --- | --- |
| Damage / Impact | R08 already moved submission/capture toward typed paths; regression-audit only unless a violation reappeared. |
| Grab | Separate holder input, ownership lifecycle, physical solver, and imperative helpers. |
| Push | Relationship/session lifecycle separate from cart/actor physics solvers. |
| Cart transport/cargo | Relationship authority already normalized; finish truthful scheduled-vs-solver classification without mirrored authorities. |
| Player input | Raw capture stays focused; mode constraints derive from authoritative focus/state, not foreign Systems. |
| Receiving | Separate phase reaction/batch state from spawn-space/package construction. |
| Day phase | Keep transition System; consumers should not use it as a global service facade. |
| Empty/legacy Systems | Remove or reclassify after verifying no current feature owns them. |

## Grab

Keep `R_HeldBy` as sole ownership authority.

Desired boundaries:
- input/session decision;
- relationship lifecycle side effects;
- physical hold solver called from body callback;
- slot/anchor/query math in non-System services where appropriate;
- typed transitions instead of direct calls into foreign Systems.

Do not create a second ownership authority in reverse caches.

## Push

Keep `R_PushedBy` as authority.

Separate:
- begin/end validation and lifecycle;
- relationship side effects;
- cart physics;
- actor follow physics.

Physics solvers may be orchestrated by Entity callbacks but must not call scheduled Systems.

## Cart transport/cargo

Preserve:
- `R_CartDrivenBy` driver authority;
- `R_CartCargo` cargo authority;
- derived caches only when justified.

Separate scheduled intent/lifecycle from body physics solvers. Do not reintroduce transport lookup through unrelated Systems.

## Player input

Raw Godot input capture should only write controller intent/edges. Control-mode constraints belong in focused intent/state processing using authoritative focus/relationships.

Do not query Push/Transport Systems as service locators.

## Damage / Impact regression gate

Do not plan another broad rewrite merely because old R22.5 text mentioned `S_Damage`/`S_Impact`.

Verify only:
- no System-instance scan/service locator;
- no direct System-to-System calls;
- physics contact capture remains separate from typed damage resolution;
- throw lifetime/attribution remains Relationship-based;
- HP changes still flow through the typed damage pipeline.

## Acceptance

- no new direct project `S_* -> S_*` service calls;
- static-only helper classes are not registered/named as scheduled Systems;
- ownership stays Relationship-authoritative;
- behavior unchanged;
- stage uses static validation only.
