# Refactoring v2.27 — execution-model acceptance checkpoint

Status: **DONE — PASS**

Зависимости: [26_execution_graph_cleanup.md](26_execution_graph_cleanup.md).

## Goal

Закрыть первую часть Phase 2: доказать, что scheduled/reactive/service ownership стабилен **до** массового vertical-domain перемещения файлов.

## Required acceptance

- полный service inventory закрыт;
- hidden System patterns устранены;
- architecture validator PASS;
- project structure PASS;
- parser всех затронутых GDScript PASS;
- профильные GUT изменённых подсистем PASS;
- один связный headless smoke основных gameplay contracts PASS;
- save/restore smoke PASS, если persistence boundary затрагивалась;
- нет новых refactor-related errors/warnings;
- временные wrappers execution-model migration удалены.
- ключевые typed flows из 40 проверены в final execution graph: единственный handler, commit-before-fact, отсутствие reentrant event cycles и повторного settlement; deferred work имеет explicit flush boundary.

## Review

Проверить ownership, execution ordering, service chains, event loops, duplicate authority, dead wrappers и unnecessary abstractions.

Каждый finding получает FIXED / ACCEPTED_WITH_REASON / OUT_OF_SCOPE_WITH_TASK.

## Gate

Это **не** разрешение начинать Code Style.

После PASS продолжить [28 — vertical-domain layout](28_domain_layout_contract.md). Полный архитектурный gate находится в [49_core_architecture_acceptance.md](../../refactoring_v2/49_core_architecture_acceptance.md).

## Review findings

- **FIXED — historical connected smoke drift.** Replaced the fixed-eight-package/RigidBody-player fixture with the actual CharacterBody player, provider-selected incoming manifest, real registration ledger, terminal Customer settlement and replay, Inventory ownership, typed damage, scheduled day transition, Night capture and fresh authored startup restore. The fixture uses authored unload markers accepted by actual truck containment.
- **FIXED — dormant registered actor indexing.** Pinned GECS `disable_entity()` disconnects structural callbacks while retaining the Entity in its archetype. Restored dormant NPC role/Brain changes therefore left the native query index stale; later activation exposed NPCs without the required Customer component. Project-owned `GameWorld.disable_entity()` preserves native disable facts/process shutdown and reconnects the six native structural callbacks. Component/per-link/batch Relationship changes remain indexed without reactivation, a second index, or addon mutation. Three focused regression cases cover role removal/replacement, relationships, repeated disable/enable and single publication.
- **ACCEPTED_WITH_REASON — pinned GECS composition adapters.** Disabled structural tracking and silent restore monitor reseeding are bounded project-owned integration contracts against checked-out GECS v8, documented in ARCHITECTURE. They are neither temporary execution-model compatibility wrappers nor alternate runtime authority.
- **ACCEPTED_WITH_REASON — Night capture and Morning-entry timing.** The captured Wallet precedes the subsequent scheduled Morning fact. Fresh passive startup must equal the captured aggregate; its first scheduled step must equal the original continuation. Both lifecycle points are asserted, including operation counts and settlement replay.

Inventory 136/136 is closed; strict lexical architecture findings/baseline are empty. Typed flows retain sole handlers, explicit queued flush ownership and commit-before-fact; GUT covers pending-vs-committed transitions, reentrancy, exact captured Component/Relationship lifetime, terminal fact replay and exactly-once Wallet settlement. No execution migration wrappers remain. No owner gameplay/visual QA is required for this gate.

## Validation

Executed 2026-10-08 after the final implementation batch:

- `python utils/validate_architecture.py --strict`: PASS, zero findings.
- Architecture validator fixtures: 17/17 PASS.
- `python utils/validate_project_structure.py`, `validate_persistence_baseline.py`, `validate_refactoring_preflight.py`: PASS.
- Godot changed-script parser: PASS, 3 final changed GDScript files, zero errors/warnings.
- GUT execution/commerce/customer/quest/contents/damage/persistence/lifetime surface: **74/74, 1128 assertions**, clean log `tests/artifacts/refactoring_v2_27_foundation_gut.log`.
- GUT registered-disabled/district snapshot/world snapshot surface: **37/37, 384 assertions**, clean log `tests/artifacts/refactoring_v2_27_disabled_gut.log`.
- Actual connected main-level headless smoke: PASS, clean log `tests/artifacts/vertical_slice-20261008-170938277.log`.
- Two-process actual Night smoke: write PASS `night_persistence-write-20261008-171338026.log`, restore PASS `night_persistence-restore-20261008-171348210.log`.

Earlier diagnostic failing runs were resolved before acceptance; all temporary probes were removed. Old-save migration remains excluded; current-format roundtrip is verified. No rendered gameplay or subjective visual QA ran.

## Current / Next

**PASS** execution-model checkpoint. Continue [28 — vertical-domain layout](28_domain_layout_contract.md), then enable dependency enforcement before owner moves. Do not start Phase 3; final authorized stop remains PASS task 49.
