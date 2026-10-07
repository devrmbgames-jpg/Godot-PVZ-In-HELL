# Refactoring v2.22 — Motion и physics boundaries

Status: **PLANNED**

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
