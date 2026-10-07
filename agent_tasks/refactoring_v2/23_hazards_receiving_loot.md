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

## Incoming validation findings from task 11

Four receiving physics fixtures reproduce on isolated pre-task11 commit 1c52565a with the same
pinned working GECS source: test_truck_shift_gate **19/23**, 148/157 assertions. Current tree shows
exactly the same failures; no unexpected script errors. Resolve during this receiving migration
before broad acceptance 27/49:

- test_partial_exit_and_rotated_cargo_use_full_body_bounds (lines 132/133);
- inherited test_blocked_cargo_preserves_batch_until_space_is_free (108/109/119);
- inherited test_full_shape_rejects_wall_and_respects_marker_edit (134/135/141);
- inherited test_authored_upper_slot_stacks_on_real_box (157).

The legacy customer_flow smoke also fails its documented historical eight-box supply expectation
at line 36; align the receiving fixture with the current district/physical supply contract. Preserve
actual full-shape occupancy, blocked placement, authored marker and stacked-body behavior; do not
weaken assertions merely to pass. No rendered QA was run or requested by these automated findings.
