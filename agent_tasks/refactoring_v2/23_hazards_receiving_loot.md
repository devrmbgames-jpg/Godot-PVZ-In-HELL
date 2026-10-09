# Refactoring v2.23 — Hazards, receiving, loot и delivery runtime

Status: **DONE**

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

## Current / Next

DONE 2026-10-08. Далее [24 — Economy, Inventory и Commerce](24_economy_inventory_commerce.md).

- `S_LootDrops` owns retry cadence, captured bounded traversal and failed-record rotation. `LootDropService.retry` and its caller are removed; `place_pending` attempts one recorded placement. Initial enqueue/registration remains an explicit transaction. Calendar, owner, policy, record membership and transient revision are revalidated around synchronous registration reactions.
- Receiving and order Systems retain cadence and capture their actual Component/calendar context. Restore invalidates queued work with transient revisions even when the authored Component and its typed array retain identity. Order and loot tickets permit one outstanding budget/attempt and do not let old callbacks clear a newer ticket.
- Hazard follow commits capture the actual relationship binding; lifetime commits revalidate the exact Components and expiration. Disabled hazards still retire. No physics transform writer was moved into a System.
- Reviewed KEEP boundaries: hazard spawn/emission/explosion/damage/retirement, remains, package delivery/history/content, phase submission, placement and order fulfillment remain explicit operations. Existing Systems/Observers own gameplay clocks and discrete triggers. The non-ECS morning truck retains its native bounded door-animation lifecycle; no artificial ECS scheduler was added for a local Godot animation.
- Four inherited receiving failures were corrected in fixtures using current authored cargo dimensions/offset, full prefab bounds and rotated cargo axes. The stacking fixture positions its runtime upper marker against actual lower-box support. Authored scenes, balance and physical assertions are preserved.
- Smoke tooling now executes both `write` and `restore` in separate Godot processes for loot/furniture and requires each exact phase completion marker. Any script/runtime error or nonzero engine exit still fails validation.

## Validation evidence

- Godot changed-script parser: **17 files PASS**, zero failures. Architecture **PASS** (2 remaining lexical findings assigned to 25), structure, persistence baseline and roadmap preflight **PASS**.
- Final GUT `refactoring_v2_23_final_gut.log`: **105/105, 1099 assertions PASS**, six actual receiving/truck/loot/furniture/hazard/current-format baseline scripts. No GUT errors, script errors, exit leaks or native crash. Additional `refactoring_v2_23_packages_final_gut.log`: **62/62, 694 assertions PASS** over receiving limits, delivery completion, remains and package contents.
- Fourteen new queued-context regressions cover cancelled records, duplicate budgets, component/relationship replacement, calendar changes, same-Morning snapshot restore and disabled/renewed hazard retirement. Snapshot tests use persisted authored policy paths and preserve current-schema roundtrip; no old-save migration.
- Headless smokes **PASS**: hazards (`hazards-20261008-135107502.log`), truck shift (`truck_shift_gate-20261008-135106957.log`), loot write/restore (`safe_loot_placement-write-20261008-140246295.log`, `safe_loot_placement-restore-20261008-140255456.log`), furniture write/restore (`furniture_arrival-write-20261008-140244065.log`, `furniture_arrival-restore-20261008-140254231.log`).
- Intermediate narrow GUT runs exposed nondeterministic native shutdown crashes / pinned addon resource leaks after passing assertions. The final complete profile, including the real base truck script, and the additional package surface both exited cleanly. Experimental fixture/cache-cleanup changes were discarded; no addon changes or error suppression. The isolated shutdown symptom is not claimed fixed.
- Acceptance **PASS**: one scheduled/reactive owner per lifecycle, no retry Service dispatcher, no duplicate runtime path. Current schema 3/IDs/resource contracts retained. No rendered gameplay, subjective visual QA or required owner QA.
