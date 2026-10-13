# R27 — исправления по ручной QA и изолированные тестовые комнаты

Status: **IN_PROGRESS**

Source QA: owner report2026-10-13, HEAD `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`.
Parent acceptance: [R26](r26_items_npc_expansion.md), [QA checklist](../qa_tasks/r26_acceptance.md).

## Task state

### Goal

Исправить все перечисленные владельцем QA-проблемы и расширить тестовую локацию.
Этот файл владеет общим scope/порядком; этапы ниже владеют своими ошибками и evidence.

### Current

Visit commitment implementation and native regressions pass; its committed review remains pending.
MCP editor connected: Godot4.7.1, ready/stopped; saved main_menu is editor-owned.
Unrelated dirty user resources/settings/addon edits must be preserved.

### Milestones / Next

1. [Сохранение плана визита](r27_service_visit_commitment.md): не переносить визит
   из-за взаимного избегания/ожидания; blocked route cancels only called recipient's approach.
2. [Обход и дистанция](r27_npc_passing_and_spacing.md): дверной проход,1.5m от агрессивных,
   взаимные угрозы/рост агрессии и исключения наблюдаемого/движущегося ангела.
3. [3D-таблички ангела](r27_angel_world_signs.md): реальные мировые таблички/Label3D вместо диалога.
4. [Вечерняя доставка](r27_evening_delivery_contract.md): ждать у своего входа; терминальный
   offer доступен только до дня личного забора.
5. [Тестовая локация/10 комнат](r27_test_lab_and_npc_rooms.md): все новые предметы/механики,
   native scene transitions туда/обратно, один архетип/две посылки в день.
   Owner answer: **10 rooms, reset on every entry**, no retained per-room progress.

Next: milestone1; main is sole writer, reuse existing read-only reviewer on immutable checkpoints.
Independent [home-night fixture mismatch](r27_home_night_fixture_identity.md) was reproduced
with12 mismatched profiles/0 active roles during milestone1 validation; repair it before closing that gate.

### Validation / completion

Focused parser/static/GUT per logical milestone; affected headless integration at milestone close.
Scene transitions require native World cleanup/re-entry coverage and exact-SHA review.
All five milestone scopes must pass implementation/testing/review before automated R27 closure.
Rendered gameplay/capture has no approval for this task; do not fabricate visual/subjective PASS.
User-reported QA proves defects, not approval to launch a new rendered playtest.

### Owner QA / blockers

Required final gameplay/readability acceptance remains open after implementation.
Known shutdown-only retention remains KNOWN_ENGINE_LIMITATION / DEFERRED.
