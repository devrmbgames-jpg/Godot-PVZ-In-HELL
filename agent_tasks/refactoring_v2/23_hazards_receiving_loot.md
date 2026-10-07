# Refactoring v2.23 — Hazards, receiving, loot и delivery runtime

Status: **PLANNED**

Зависимости: [22_motion_physics.md](22_motion_physics.md), [17_combat.md](17_combat.md).

## Goal

Проверить gameplay services, связанные с hazard lifetime/spawn, receiving, delivery, loot и order progression, и убрать remaining hidden schedulers.

## Scope

- hazard spawn/follow/lifetime;
- receiving/order delivery;
- loot/drop placement lifecycle;
- morning/truck/furniture runtime paths;
- package lifecycle service boundaries.

## Direction

Scheduled lifetime/progression = System.
Discrete spawn/destruction/setup = Observer.
Placement/calculation/factory/transaction = Service/Solver/Rules по роли.

## Acceptance

Каждый lifecycle имеет один scheduler/reactive owner.
Не создаётся сервисная цепочка, дублирующая `S_*`/`O_*`.

## Validation

Hazards/package/receiving/order/loot профильные tests + smoke по необходимости.
