# Refactoring v2.22 — Motion и physics boundaries

Status: **DONE**

Зависимости: [21_grab_push_slots.md](21_grab_push_slots.md), [16_npc_route_service_role.md](16_npc_route_service_role.md).

## Goal

Проверить motion/physics код отдельно, не применяя ошибочно правило «всё в System» к engine-bound physics callbacks.

## Scope

- `S_NpcIntent`, player motion/input Systems;
- `CharacterMotionSolver`, `KinematicCharacterSolver` и related solvers;
- physics callback ownership;
- movement calculations/services;
- navigation/avoidance boundaries после NPC route refactor.

## Decisions

- код, который обязан выполняться внутри `_integrate_forces`, остаётся Solver;
- pure effective-speed/traction calculations могут быть Rules/Calculation;
- scheduled intent/navigation progression остаётся Systems;
- Entity содержит только тонкий Godot callback glue.

## Acceptance

Physics ownership документирован и не размыт архитектурным рефакторингом.
Нет artificial no-op Systems, созданных только чтобы вызвать solver.

## Validation

CharacterBody/RigidBody physics профильные tests + parser. Rendered feel — только owner QA при необходимости.

## Current / Next

DONE 2026-10-08. Далее задача 23 — Package lifecycle/damage.

- `MotionRules` owns shared pure effective-speed/material-traction calculations. Removed `CharacterMotionSolver.effective_speed`; all Systems, route solver, native adapters, tests and smoke callers migrated without facade.
- Native RigidBody callback and independent motion/look/impact/driver/push contributions preserved. No callback work moved into a System.
- Native CharacterBody callback now independently composes slide motion → walking push → impact capture → support sample. `KinematicCharacterSolver` no longer calls the other solvers. `KinematicMotionSample` is an ephemeral immutable-by-contract pair of observed/desired velocities, not persisted authority; actual physical body retains transform/velocity.
- Reviewed scheduled input/intent/jump/sprint/crouch, native support/impulse/transport, per-frame navigation/avoidance and due-step route planning/progress boundaries. Route planner initializes a newly published cursor, S_NpcIntent advances it; floor/avoidance caches are derived observations. No artificial no-op System. Documented the concrete order/per-field authority in `content/ARCHITECTURE.md`.
- Headless integration exposed inherited test-policy leakage: a preceding district fixture sets the cached Definition pause to zero. Positive-pause regression now explicitly configures/restores its own positive interval; gameplay behavior unchanged, original blocking/approach assertions preserved.

## Validation evidence

- Godot parser **12 changed files PASS**, final changed-fixture parser **1 file PASS**, zero failures.
- GUT `refactoring_v2_22_physics_gut.log`: **137/137** non-district tests PASS over native CharacterBody/RigidBody, generic grip, NPC intent, jump, stamina/speed/hunger, sharp-turn/seam/jump/slot headless controls and warehouse navmesh. District surface initially **53/54** because zero-pause fixture leakage; isolated scenario **1/1 PASS**, then full corrected `refactoring_v2_22_district_final_gut.log` **54/54, 393 assertions PASS**. No acceptance assertion removed.
- Actual native/Jolt headless cart smoke **PASS** (`cart_transport-20261008-133555214.log`); actual main-level hunger/carry/perception/combat smoke **PASS** (`hunger-20261008-133808718.log`). No rendered gameplay or subjective visual QA.
- Architecture **PASS** (2 remaining findings owned by 25), structure, persistence baseline and roadmap preflight **PASS**; final `git diff --check` PASS. No old pure API callers, no nested push/impact calls in native motion solver.
- Acceptance **PASS**. Current schema/path contracts unchanged; no owner gameplay/visual QA required for this preserved-order architecture slice.
