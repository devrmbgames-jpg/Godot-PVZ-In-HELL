# R27 — исправления по ручной QA и изолированные тестовые комнаты

Status: **DONE**

 — принято владельцем 2026-10-15.

Source QA: owner report2026-10-13, HEAD `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`.
Parent acceptance: [R26](r26_items_npc_expansion.md), [QA checklist](../../../.qa/tasks/r26_acceptance.md).

## Task state

### Goal

Исправить все перечисленные владельцем QA-проблемы и расширить тестовую локацию.
Этот файл владеет общим scope/порядком; этапы ниже владеют своими ошибками и evidence.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Visit commitment implementation, native regressions and exact-SHA review pass after RV-001 repair
at `1c225a959f7e408cb90d42a43a5ee7bef39df1ab`; owner acceptance remains open.
MCP editor connected: Godot4.7.1, ready/stopped; saved primitive test hall is editor-owned.
Unrelated dirty user resources/settings/addon edits must be preserved.

### Milestones / accepted scope

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Owner instruction2026-10-14: after completing R27, finish the remaining
[R26 tasks](r26_items_npc_expansion.md). Work resumed by the owner's subsequent instruction.

1. [Сохранение плана визита](r27_service_visit_commitment.md): не переносить визит
   из-за взаимного избегания/ожидания; blocked route cancels only called recipient's approach.
2. [Обход и дистанция](r27_npc_passing_and_spacing.md): дверной проход,1.5m от агрессивных,
   взаимные угрозы/рост агрессии и исключения наблюдаемого/движущегося ангела.
3. [3D-таблички ангела](../r27_angel_world_signs.md): реальные мировые таблички/Label3D вместо диалога.
4. [Вечерняя доставка](r27_evening_delivery_contract.md): ждать у своего входа; терминальный
   offer доступен только до дня личного забора.
5. [Тестовая локация/10 комнат](r27_test_lab_and_npc_rooms.md): все новые предметы/механики,
   native scene transitions туда/обратно, один архетип/две посылки в день.
   Owner answer: **10 rooms, reset on every entry**, no retained per-room progress.

Evening delivery checkpoint `136cfa18cbc5d6e9e0f20d5c8e58347ecdd2bf31` passes native gates;
Review PASS from base `1c225a959f7e408cb90d42a43a5ee7bef39df1ab`; no material findings.
Signboard checkpoint `2636f85dd143841f8586827ba3ee996056b9456a` passes native gates;
Review PASS from base `136cfa18cbc5d6e9e0f20d5c8e58347ecdd2bf31`; no material findings.
Reviewer architecture/style PASS, validation NOT_RUN;400s, UTC08:51:49?08:58:29.
MCP includes bounded native path diagnostics for new project-owned scripts.
Physical passing/spacing now passes native physics, social/freeze and production-week gates.
Passing checkpoint `7e67e938e154c071203c5efcd27c8b539c66aa4b`: RV-001 emergency-priority bug
FIXED/tested/reviewed at `5c1028cf43b39f40f19aec47aa1442686a87944e`; targeted review PASS46s.
Current accepted findings resolved; all five milestones implemented/tested/reviewed.
Main is sole writer; reuse existing read-only reviewer on immutable checkpoints.
Independent [home-night fixture mismatch](r27_home_night_fixture_identity.md)
is repaired, tested, reviewed and archived; original FAIL evidence remains in its task.

### Implementation checkpoint before owner acceptance

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Owner resumed work2026-10-14. Complete R27, then the remaining R26 tasks.
Committed HEAD `5c1028cf43b39f40f19aec47aa1442686a87944e`.
Last targeted review: base `7e67e938e154c071203c5efcd27c8b539c66aa4b`,
target `5c1028cf43b39f40f19aec47aa1442686a87944e`, PASS/no material findings,
UTC09:53:02?09:53:48,46s. Sole reviewer is terminal; no second reviewer running.
All accepted R27 findings are FIXED in their owning task records; owner QA remains open.
One replacement immutable review was collected; no reviewer is working on a second checkpoint.
R27.5 has native MCP-authored ten rooms/presets/portals, all16 physical catalog
items and controlled light zones. Editor hall was saved after assigning16 explicit item IDs.
Real portal transitions/reset/cleanup PASS496 checks across10 rooms/20 entries, exit0;
`.artifacts/npc-room-transitions-20261014-052713065.log`.
Room bootstrap/three daily physical supplies and same-recipient registered cases GUT2/600 PASS
(`gut-20261013-193043024`); game-session GUT6/43 PASS (`gut-20261013-193503385`).
R27.5 checkpoint `25f6de748304171b935dba4084f8de78088f9906` committed.
Review PASS: BASE `5c1028cf43b39f40f19aec47aa1442686a87944e` ->
TARGET `25f6de748304171b935dba4084f8de78088f9906`; no material findings,240s.
Reviewer architecture/style PASS, validation NOT_RUN. Editor-only scene-authoring heuristic
reviewed compliant/REJECTED RV-001 in R27.5; raw validator FAIL preserved there.
Full relevant final GUT181/2709 PASS; native parser/MCP/formatter/strict structure gates PASS.
Production7day and connected2day/write/fresh restore native PASS; wrapper shutdown warnings
KNOWN_ENGINE_LIMITATION/DEFERRED. Full evidence owned by R27.5.
Windows test-level export/menu+level startup PASS; `.export/TEST_LEVEL.cmd`.
Preserve unrelated user edits, including .codex/config.toml, resource/settings/addon changes.
Next: remaining R26 acceptance against the reviewed R27 HEAD. Required
[R27 owner QA](../../../.qa/tasks/r27_acceptance.md) remains pending until actual acceptance.

### Validation / completion

Focused parser/static/GUT per logical milestone; affected headless integration at milestone close.
Scene transitions require native World cleanup/re-entry coverage and exact-SHA review.
All five milestone scopes must pass implementation/testing/review before automated R27 closure.
Rendered gameplay/capture has no approval for this task; do not fabricate visual/subjective PASS.
User-reported QA proves defects, not approval to launch a new rendered playtest.

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Shutdown-only retention остаётся KNOWN_ENGINE_LIMITATION / DEFERRED; прежние технические evidence сохранены.
