# Refactoring v2.26 — очистка execution graph

Status: **DONE** (2026-10-08)

Зависимости: [25_persistence_remaining.md](25_persistence_remaining.md), все execution tasks 11–24 завершены. Foundation 40 уже завершена до 11; поздние layout/core tasks 28–33 и 41–49 не являются prerequisites этого checkpoint.

## Goal

Сделать финальный статический проход по execution model и удалить остаточные wrappers/aliases, появившиеся во время миграции.

## Work

- найти project-owned `Service.tick/update/process`;
- найти Systems, чей process только делегирует generic service method;
- найти broad ECS queries внутри remaining scheduled service paths;
- проверить `deps()` после появления новых Systems;
- удалить orphan wrapper methods/files;
- проверить class_name/path naming;
- проверить, что System не вызывает System;
- проверить observers/events на циклы и дублированные transitions;
- обновить `content/ARCHITECTURE.md` только если итоговая реализация уточнила контракт.

Task 24 regression confirmed a concrete queued-lifetime trap: binding a Node/Entity directly to a typed Callable argument raises an engine type error if that Node is freed before flush, before any is_instance_valid guard inside the callback can run. Inventory death completion now captures WeakRef and resolves its typed Entity inside the callback. Audit the migrated queued System/Observer callbacks for the same actual freed-owner case (not only disabled/component-replaced cases), and close relevant lifetime paths with safe captured references and regression coverage before checkpoint 27. Resource Component identity guards remain necessary after resolving the owner. This is a validation/ownership issue, not an old-save migration or gameplay choice.

## Acceptance

Architecture validator имеет пустой migration baseline либо только документированные engine-bound исключения.
Execution order можно восстановить по Systems/Observers без чтения service graph.

## Validation

Structural architecture validator + parser всех изменённых files + targeted dependency/order tests.

## Implementation / Review

- FIXED: all direct queued typed Entity/native-body callbacks in migrated Systems/Observers now capture WeakRef, resolve the owner inside the callback, then validate registration/participation and captured Component/Relationship/context identity. Optional null fixture ownership remains distinct from an expired runtime owner; expired planning commands complete with `session_unavailable`.
- FIXED: six queued external operation bindings now commit through the owning System/Observer with captured authority. No public synchronous Entity API was converted into a scheduler or generic compatibility wrapper.
- FIXED: eight pinned GECS structural relationship closures also failed free-before-flush: Godot reports `Lambda capture ... was freed` before their internal validity guard. Project owners now resolve WeakRef and remove only the exact still-attached captured Relationship. A regression proves an old command cannot pattern-match/remove a replacement binding. Addon files were not edited.
- FIXED: remaining customer/session/setup/damage callbacks capture queried Component identity; old work rejects removed/replaced aggregates. Start-shift/liquid/toxin commits gained missing exact-state checks. Greeting revalidates after synchronous request dispatch.
- FIXED: committed package opening captures initiator ID; deferred contents release preserves attribution after the optional initiator is freed. Real unsupported placement regression verifies retained pending-loot records and one contents commit.
- FIXED: architecture guard rejects queued typed Node binds, pinned unsafe structural closures in project owners, and System imperative calls to another System. Five new behavioral validator fixtures cover positive/negative cases; no new baseline permissions.
- ACCEPTED_WITH_REASON: synchronous `S_Impact.body_exited` binds the same native signal emitter; freeing that emitter removes its connection, with no pending World callback. Native physics solvers retain engine callback ownership. `NpcBrainService.update_tree` advances one explicitly selected manual native BT; cadence/iteration/order remain in AI Systems. These are documented runtime contracts, not migration allowances.
- ACCEPTED_WITH_REASON: solver/geometry helpers still in horizontal roots are moved by the declared Phase 2B layout tasks; no service tick or competing runtime writer remains.
- OUT_OF_SCOPE_WITH_TASK_27: historical `vertical_slice` smoke predates the current CharacterBody player and district supply/provider contract (first wrong player cast, then obsolete fixed eight-package expectation). The trial fixture correction was reverted; checkpoint 27 will replace this connected acceptance surface with current main-level contracts before PASS. This is a test-tooling repair, not an owner gameplay/design choice.

## Validation result

- Godot 4.7.1 changed-file parser: **PASS**, 69 files, 0 failures.
- Strict architecture: **PASS**, 0 findings, empty migration baseline; project structure, persistence baseline and refactoring preflight: **PASS**.
- Architecture validator behavioral fixtures: **17/17**, including all five new execution/lifetime rules.
- GUT order/lifetime/customer planning/outcomes/native AI scheduling: **80/80**, 516 assertions (`tests/artifacts/refactoring_v2_26_order_gut.log`).
- GUT production queued lifetime/package contents/grab/physical slots: **125/125**, 790 assertions (`tests/artifacts/refactoring_v2_26_interaction_gut.log`). New lifetime suite includes 13 tests for actual query/enqueue paths, free-before-flush, removed roles/replaced state, exact Relationship retirement and expired optional initiator attribution.
- GUT typed boundaries/combat/NPC attacks/morning truck/shift gate/safe loot/furniture: **112/112**, 928 assertions (`tests/artifacts/refactoring_v2_26_boundaries_gut.log`). No relevant runtime error/warning or shutdown resource diagnostics in final GUT runs.
- Headless hazards smoke: **PASS**, `tests/artifacts/hazards-20261008-162112033.log`.
- `git diff --check`: **PASS**. No formatter or rendered/subjective QA run claimed.

## Current / Next

DONE. Continue task 27 execution-model acceptance; its current connected main-level smoke and save/restore gate must pass before Phase 2B. No user QA or product choice required for this implementation.
