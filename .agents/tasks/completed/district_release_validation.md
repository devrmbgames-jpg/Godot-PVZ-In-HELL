# Район — итоговая интеграция и Windows QA

Status: **DONE** — принято владельцем 2026-10-15.

Родительский этап: [Утренняя машина](district_morning_truck.md). Порядок выполнения: [общая задача](district_service_update.md).

Зависимости: автоматическая приёмка и review/triage [gate](district_truck_shift_gate.md),
[обратного груза](district_truck_returns_resale.md), [snapshot](district_save_schema_3.md),
[инструментов](district_bin_cleanup.md) и
[контракта navigation validator](warehouse_navigation_validation_contract.md).
Их открытая owner QA не блокирует подготовку автоматической приёмки и сборки.

## Task state

### Goal

Завершить связную автоматическую приёмку всех этапов и подготовить runnable Windows QA-сборку с отдельными ручными пунктами.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Connected all-ten production-roster gate restored and reviewed. Reviewed connected-fixture checkpoint
`1f37ddd1c3136c2b6094ed8c7131a3e9d2ce8dee`; BASE `ca6ed1425d617b504b6afaa39759e65e0b9fc5c7`.
Targeted repair cycle1: ARCHITECTURE/STYLE PASS, no findings; reviewer VALIDATION NOT_RUN.
RV-001..005 are FIXED; source reviews with FAIL remain recorded below. Native write/restore
PASS, exits0/0; wrapper write FAIL only at known shutdown retention. Required owner QA is open.

Actual shifts/Nights1/2 and fresh-process Morning3 cover terminal LOST/note/offers,
success/refusal/failed promise, SALE/raw DISPOSAL/RETURN, physical furniture, queue3,
counter arrivals>=2, warned light-specific timeout with negative controls, all seven durable
aggregates and replay counters3/3+2. Player input selects Fire's genuine day1 parcel for one
manual LOST and leaves its real day2 parcel unscanned: unresolved WAREHOUSE, number0,
no invented delivery/LOST/payment. Fire AI/aura/damage and production profiles remain active.
Private DEF ambient0.3 and existing5s light wait provide ordinary-service fixture inputs;
authored DEF is restored before each Night. Native safe-home wait/dialogue close and awaited
actual inspection own outcomes; player withdraws indoors during inspection. Home pose remains
fixture input; actual walking/default ambient0.15/authored light timeout60s require owner QA.

Production gameplay checkpoint is `2c18343d39d0a3ee774c9f80c33ff16d7e6d70c4`;
default production week162731685 PASS (unchanged >=6/8), see [R26.5](r26_5_integration_persistence_validation.md).
Runnable QA build `.export/windows/20261013-063204Z-2c18343d-r26-contact-fire-only/`; export/menu/level120frames PASS,
dirty worktree recorded. Owner-requested wide-fire removal/contact reduction is included in the new export;
compiled gameplay and external connected-fixture evidence are distinguished in the manifest. Historical build20261011 remains prior evidence.
Next: required [owner acceptance](../../../.qa/tasks/district_release_validation.md); no automated/review blocker remains.

### Validation

Current native checks on preserved dirty worktree (not immutable runtime checkout):

- GUT async-counter/native light retirement: PASS42/42, 276 assertions;
  `.artifacts/godot_agent/gut-20261013-030903633.stdout.log`, wrapper PASS.
  Earlier fixture trials failed signature/light-entry/order setup; none are counted as PASS.
- Parser2/2, zero failures, native exit0: `parsefiles-20261013-030947898`;
  wrapper FAIL only known shutdown3RID/293Resource/VariantPools retention.
- Full connected native write/restore PASS, exits0/0:
  `tests/artifacts/district_release-write-20261013-162956129.log` and
  `tests/artifacts/district_release-restore-20261013-163149620.log` (actual exit in adjacent `.result.json`).
  Write wrapper FAIL only shutdown35RID/418ObjectDB/327Resource/VariantPools; restore ran
  separately in a fresh process. All original outcome/timeout/replay gates retained.
- Inspection12/163 and district delivery22/166 PASS, wrappers PASS on source fixture checkpoint:
  `gut-20261013-025047741` / `gut-20261013-025105226`; logic unchanged by async-loop repair.
- Incremental formatter/lint2files, strict architecture0findings, project structure,
  staged agent-change gate (0 eligible gameplay files) and scoped `git diff --check` PASS.
- Connected-fixture targeted review: PASS, UTC03:10:34..03:11:23, 49s; reviewer validation NOT_RUN.
  MCP session inspection returned no live editor; native headless checks ran independently.
  Shutdown-only retention is KNOWN_ENGINE_LIMITATION / DEFERRED. Rendered QA NOT_RUN.

Historical acceptance before R26 (2026-10-12, preserved dirty worktree):

- GUT `test_world_snapshot`: PASS 30/30, 352 assertions;
  `.artifacts/godot_agent/gut-20261011-163946671.stdout.log`.
  `test_game_session`: PASS 6/6, 43 assertions (`gut-20261011-164042998`);
  `test_district_service_queue`: PASS 51/51, 340 (`gut-20261011-170049069`). Wrappers PASS.
- PASS: incremental formatter/lint, agent-change gate, strict architecture/domain structure,
  domain dependencies, project structure и scoped `git diff --check`.
- Dialogue native compiler/current imported data: PASS 3/3, zero failures;
  `offlinescript-20261011-164407279.stdout.log`. Native exit 0; wrapper FAIL только
  по shutdown RID/Resource retention, KNOWN_ENGINE_LIMITATION / DEFERRED.
  Воспроизводится `utils/godot_agent.ps1 -Action OfflineScript
  -ScriptPath res://utils/validate_district_dialogues.gd` при закрытом редакторе.
- Final parser `parsefiles-20261011-170129159`: 2/2, native exit 0, runtime/script errors нет;
  wrapper FAIL по shutdown-only retention. До этого параллельный parser native crash
  (`parsefiles-20261011-164356823`) не является PASS; последовательный повтор завершился.
- Live MCP: проектный editor PID 15008, ownership report без unsaved scenes;
  финальный `script_patch` smoke checked/reloaded, diagnostics empty.
  Editor log содержит четыре ошибки намеренных cyclic authoring fixtures, вне этого smoke;
  это не shutdown retention и не доказательство чистоты всего editor log.
- Windows export/headless menu+main level startup: PASS через `utils/export_windows.ps1
  -Label district-release`; manifest `.export/windows/20261011-165403Z-4cec6443-district-release/build_info.json`.
  Источник checkpoint 4cec6443 + сохранённые dirty worktree изменения; это не immutable build.
- Connected native write/restore PASS, exit 0/0, final reviewed code checkpoint:
  `tests/artifacts/district_release-write-20261012-025825843.log` и
  `tests/artifacts/district_release-restore-20261012-030018398.log`.
  Write wrapper FAIL по shutdown-only retention; restore выполнен отдельно через
  `Godot --headless --fixed-fps 60 --path <project> res://tests/smoke/district_release_smoke.tscn
  --quit-after 48000 -- restore`, поскольку wrapper останавливается после write FAIL.
  Три restore/result и два post-operation gates выполнены. Runtime/script errors нет;
  KNOWN_ENGINE_LIMITATION / DEFERRED; wrapper FAIL не объявлять wrapper PASS.

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Связанные чеклисты: [связный чеклист итоговой сборки](../../../.qa/tasks/district_release_validation.md)

## Границы и владельцы

- Существующие профильные тесты, `tests/smoke/`, штатные validation/export инструменты и `.export/`.
- Четыре родительские задачи, корневая задача и новый чеклист `.qa/tasks/`.

Применять по области: [gut-testing](../../skills/gut-testing/SKILL.md), [godot-ai-mcp](../../skills/godot-ai-mcp/SKILL.md).

## Работы

- [x] Parser, актуальность импортированных диалогов, структура и профильный GUT.
- [x] Многодневный headless smoke: второй день, очередь/свет, terminal/LOST, доставка,
  мебель, машина и сохранение/восстановление без повторных операций.
- [x] RV-001/002/003 проверены; targeted re-review собран и triaged.
- [x] Windows QA в .export и headless startup меню/основного уровня.
- [x] Фактические команды/результаты записаны; native/wrapper статусы разделены.
- [x] Оформить ручные пункты маршрутов, BT, мерцания, UI, ловушки, мебели и машины.
  Обязательная owner acceptance оставляет задачу активной до решения владельца;
  чеклист не отменяет её. DONE/архивирование — после всех required gates и review/triage;
  явно отложенные subjective polish пункты можно передать в `.qa/tasks/`.
- [x] Обязательная owner acceptance, включая authored 60-секундное ожидание света.

## Review findings

BASE_SHA: `ca6ed1425d617b504b6afaa39759e65e0b9fc5c7`.
TARGET_SHA: `1f37ddd1c3136c2b6094ed8c7131a3e9d2ce8dee`.
Collected targeted repair cycle1 UTC2026-10-13 03:10:34..03:11:23 (49s):
ARCHITECTURE/STYLE PASS, no findings; reviewer VALIDATION NOT_RUN.
Same existing read-only reviewer reused serially; Main owns fixes and actual native validation.
Source review BASE `433380e05cc7509c911936000a884e7f0f7862d5`
-> TARGET `ca6ed1425d617b504b6afaa39759e65e0b9fc5c7` remains ARCHITECTURE FAIL by RV-005,
STYLE PASS / VALIDATION NOT_RUN, UTC02:52:23..02:55:45 (202s).
Main checked source/current HEAD and deduplicated by owner/symbol/violated contract.
Historical source review BASE `6120e69b93de80cfa2c30b4dc2798cc41185659f`
-> TARGET `22ec1db34b4c0b5962b0a5f8f92e65169c8633cf` found RV-001/002.
Fix checkpoint: `4cec64434b4937a2f032806d56c3952792687efd`; независимый read-only
review собран, STYLE PASS, ARCHITECTURE FAIL по RV-003, VALIDATION NOT_RUN.
Targeted cycle 1 `4cec64434b4937a2f032806d56c3952792687efd` →
`0f2d65b980c53a22337736e6b5b9b2cbf07bcc42`: no material findings,
ARCHITECTURE/STYLE PASS; reviewer VALIDATION NOT_RUN. Main выполнил проверки выше.

- RV-001 (R1), P2 FIXED `4cec64434b4937a2f032806d56c3952792687efd` + fixture fix ниже.
  `_serve_counter`: `deferred_day` + LIGHT_AVERSION не доказывали light
  timeout. `NpcServiceRole.defer_visit` переносит визиты и по другим причинам.
  Наблюдать у одного visit WAITING_FOR_DARKNESS и `light_warning_started`, затем
  light-specific `defer_reason` из authored service BT; сверить отсутствие settlement.
  Перенос из-за опасности/недоступности не должен удовлетворять этой проверке.
- RV-002 (R2), P2 FIXED `4cec64434b4937a2f032806d56c3952792687efd`.
  `_restore_acceptance`: полные доменные агрегаты/physical goods проверялись
  до повторных `fulfill_one`, `complete`, `finish_evening`; после них — только wallet.
  Сверять durable aggregates и физические goods также после повторных операций,
  до следующего restore. Изменение памяти обещаний, visits/history или commerce должно
  проваливать acceptance даже при неизменном wallet; не ослаблять completion counters.
- RV-003 (новый reviewer R1), P2 FIXED `0f2d65b980c53a22337736e6b5b9b2cbf07bcc42`:
  `_stage_light_recipients` до `_unload(2)` меняет только pose, но native `NpcServiceRole.begin`
  может повторно размещать не-STREET личность. Подтверждение: write
  `district_release-write-20261012-024848572.log` FAIL, npc/7 ROUTE_BLOCKED без warning.
  Fix owner Main: staging один раз после создания native QUEUED роли; native write/restore
  и targeted re-review PASS. Source review intervals 97/47 seconds; serial/token comparison
  NOT_MEASURED, это не завершает parallel pilot.

- RV-004/P2: current connected fixture inputs failed on source
  `433380e05cc7509c911936000a884e7f0f7862d5` (native write114552126 FAIL, restore NOT_RUN).
  Matched legacy control also failed with current floor pressure; this does not prove a roster-only bug.
  Native queue diagnostic showed actual danger/path deferrals; light control verified player HP0/controlfalse.
  FIXED `ca6ed1425d617b504b6afaa39759e65e0b9fc5c7`: valid player-selected
  parcel/offer inputs, private ambient copy, native safe-home wait, native dialogue close,
  awaited actual inspection with player indoors. All original gates preserved; unscanned Fire order added.
  Native write124709286/restore124920790 PASS, exits0/0. Latest targeted review closes the distinct RV-005 repair.
- RV-005 (ca6 reviewer R1), P1 FIXED `1f37ddd1c3136c2b6094ed8c7131a3e9d2ce8dee`; source
  `ca6ed1425d617b504b6afaa39759e65e0b9fc5c7`, `_serve_counter`.
  The captured query survives awaited `_give_box`; another native light timeout can remove
  C_CustomerAgent before the next candidate's `agent.visit_id` dereference.
  Fix owner Main: revalidate captured Entity membership and fresh role after the genuine await boundary.
  Native regression42/276 executes the actual smoke traversal with light BT retirement during
  suspended first handoff and preserves unresolved order/declaration/payment semantics.
  Full connected write/restore and targeted repair cycle1 review PASS; no ACCEPTED findings remain.

Пункты относятся к [connected smoke](../../../tests/smoke/district_release_smoke.gd).
Открытые ACCEPTED P2 блокируют DONE; engine shutdown deferral их не отменяет.

## Критерии завершения

- Автоматическая интеграция имеет подтверждённый результат и runnable QA-сборку.
- Реализация, автоматическая приёмка и review/triage распределённых задач завершены;
  ручная приёмка явно записана и не объявлена выполненной. До закрытия обязательной
  owner acceptance задача остаётся OWNER_QA, а родительский этап не становится DONE.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.

