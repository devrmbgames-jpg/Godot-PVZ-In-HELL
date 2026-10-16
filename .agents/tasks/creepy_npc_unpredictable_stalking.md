# Жуткий — скрытное сближение и сервисный контакт

Status: **OWNER_QA**
Technical: **IN_PROGRESS**
Execution order: **10**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/creepy_npc_unpredictable_stalking.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Скрытный подход, ограниченный эпизод и будничная реакция после обнаружения.
Успех только при последующем реальном наблюдении на расстоянии строго <2.5 м;
пауза после успеха минимум 30 активных секунд. Нет всеведения, телепорта или погони без бюджета.
Задняя точка считается сервисным прибытием: номер своей посылки объявляется после
обнаружения; обычные очередь, резерв, тайм-ауты, осмотр, выдача и сохранения обязательны.
Полный контракт, включая прототипные настройки и отмены, остаётся в Source.

## Current

M1/M2 свободного поведения и M3a инструмента nested BT insertion приняты; не открывать заново.
C3 runtime/schema26 сохранён в `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`.
Review BASE `e45ca4d8251ffc43fdce1ab111a8afc32ac85722`, TARGET
`c6c850f6d28d3ea75e6575548808bc9053b2be87`: одно принятое P2 RV-001, других findings нет.
RV-001: watchdog достижимого, но физически застрявшего rear-route откладывал весь визит.
Исправление у O_CustomerNpcInterruption различает точный активный rear motion token,
освобождает только обход и будит обычный подход, сохраняя elapsed/резерв/историю источника.
C3 технически COMPLETE. RV-001 FIXED: `d1b19fc4abbf2ccc27b8d7e89a7dc639fb05b348`,
GUT38/320 и targeted re-review PASS/no findings (цикл1/2), BASE
`dccea7c57b4cf6fbb3b7e63285023d1432a27322`, TARGET `d1b19fc4abbf2ccc27b8d7e89a7dc639fb05b348`.
Reviewer execution NOT_RUN; native gates выполнил main. C4 остаётся обязательным OWNER_QA.
Отдельный structure compatibility fix `dccea7c57b4cf6fbb3b7e63285023d1432a27322`
reviewed PASS/no findings по BASE `c6c850f6d28d3ea75e6575548808bc9053b2be87`.

Rear SERVICE использует обычный резерв и фиксированную точку,5s budget,1.5x intent speed;
физикой/выдачей/оплатой владеют прежние подсистемы. Достижение точки до очередного BT-такта
тоже считается arrive. Номер открывается при реальной видимости; skip под взглядом/cooldown
закрывает источник текущего посещения, expiry само не создаёт следующую попытку.
CustomerVisit.stalking_visit_count — durable; C_Agent/target Relationship/route — transient.
Схема26/native golden/preflight согласованы, старые схемы отклоняются с сохранением файла.

## Work packages

| Пакет | Граница / состояние |
| --- | --- |
| C1 | M1/M2: свободные эпизоды, сохранённые паузы/выборы, отмены. COMPLETE, не повторять. |
| C2 | M3a: безопасная native вставка в BT через companion MCP. COMPLETE, не переизобретать. |
| C3 | Закончить существующий M3b целиком: rear SERVICE → arrive → обнаружение/номер → handoff/осмотр → сохранение/загрузка. COMPLETE. |
| C4 | Использовано7/8; case8 ещё разрешён/NOT_RUN. Case1 PASS только skip; cases2–6 INCONCLUSIVE в целом. Case7 обнаружил RV-002, номер после реального обнаружения не объявлен. |

C3 — один согласованный пакет реализации/проверок/ревью, не отдельное ревью каждого
поля schema или leaf. Не добавлять новые хоррор-механики и не переписывать C1/C2 без дефекта.

## Entry points / dependency gates

Начать с NpcServiceRole/CustomerVisit, сервисных bindings/sensor и bt_npc_service,
затем перечисленных в Source NpcStalkingService/Queries/Rules и тестов service/queue/stalking.
Customers владеет визитом/живым контактом; NpcRecord — личной историей/паузы через свой Service.
C3 использует технически принятый [общий handoff](automatic_parcel_handover_and_wrong_recipient_reactions.md);
его отдельная субъективная QA не блокирует интеграцию. Не ждать полного DONE соседей.

## Next

Выполнить разрешённые C4 случаи по
[QA-карточке](../../.qa/tasks/creepy_npc_unpredictable_stalking.md): собрать exact-SHA review исправления
RV-002 у CustomerGreetingService до зависимого case8. Native default MANUAL regression теперь PASS.
Остался один разрешённый rendered case; расширять бюджет/повторять закрытые случаи нельзя.
Parcel dialogue migration085f14111a20078d393e0ad4556bf782a4309ec3 reviewed PASS/no findings;
финальный H4 использовал8/8, повторять нельзя. Runner Q1/Q2 archived. Не объявлять task DONE до C4.

## Validation / review

M1/M2/M3a evidence и полные review SHA сохранены в Source; их принятое состояние не изменялось.
Финальный C3 native GUT36/36,290 assertions, stderr0: `.artifacts/godot_agent/gut-20261016-094427621.{stdout,stderr}.log`.
Это terminal результат прерванного запуска; handle теперь отсутствует, повтор не запускался.
Дополнительные затронутые scopes PASS из того же implementation package: stalking27/245
(`093411836`), persistence15/802 (`093429931`), service_queue51/342 (`093515367`),
creepy_dialogue36/1012 (`093618516`), companion11/97 (`093715748`); общий prefix `gut-20261016-`,
все stderr0. Последние service-only race/source guards покрыты финальным36-test suite.
Native ParseFiles23/0 PASS: `parsefiles-20261016-154457946.{stdout,stderr}.log` в той же папке.
Two-process headless delivery/save PASS: `creepy_c3_delivery_20261017.json` и phase raw logs;
оба native exit0, completion markers, stderr0. Старый smoke wrapper вернул FAIL из-за отсутствия
restart registration/несовпадения generic marker; это не runtime failure и не исправленный runner.
Formatter26/strict architecture0/persistence inventory PASS для C3 baseline.
Structure compatibility теперь PASS; tooling regressions18/18 PASS.
RV-001 red: native reachable/stalled watchdog снял роль (raw `creepy_c3_rv001_red.*.log`).
Repair: native GUT38/38,320 assertions,stderr0 PASS (`gut-20261016-155557405.*.log`);
включает две новые проверки настоящего route owner/observer: rear fallback и ordinary defer.
Repair MCP2 checked/empty; formatter2,strict architecture0,structure,diff-check PASS.
Comment-only MCP hot reload initially returned43; subsequent native path diagnostic checked/empty,
а свежий native parser PASS. Эти transient diagnostics не классифицировались как shutdown.
C3 baseline review: RV-001 FIXED; targeted re-review PASS/no findings,repair1/2 (SHA выше).
QA docs review BASE `d7fbb8f6a06d2cd30acbe5235bb7098364200e92`, TARGET
`4ba8dddc15225808e09b0ef3558a805203ea7145`: PASS/no findings, execution NOT_RUN.
Rendered C4:7/8 использовано; полная приёмка остаётся открытой, RV-002 блокирует disclosure.

RV-002 — ACCEPTED P1, CustomerGreetingService.announce_order: uses_quick_visit отклоняет
реальный default MANUAL визит после заднего контакта/обнаружения. Case7: физический контакт,
дистанция1.41м, memory1, pending=false, зарегистрированный номер4, order_announced=false,
message="Хрип · за посылкой". `.artifacts/creepy-c4-085f/07-observation.json`.
Исправление использует существующий достигнутый service_contact_position и visibility guard
rear_contact_pending; обычный manual visit остаётся без автообъявления, registry/once guards сохранены.
Red native39:38PASS/1FAIL (новая default policy проверка, `gut-20261016-175904455.*.log`).
Green native39/336,stderr0 PASS (`gut-20261016-180035798.*.log`), MCP2 checked/empty,
formatter2, strict architecture0, structure/diff PASS. Reload43 был transient; native path diagnostic
и fresh-process GUT чистые. Review REVIEW_PENDING; Technical IN_PROGRESS до triage. Repair cycle1/2.

## Owner QA / blockers

Владелец разрешил до8 C4 rendered/playtest случаев 2026-10-17; использовано7/8.
Case1 PASS только ветки пропуска; case2 INCONCLUSIVE в целом, ограниченность подхода и отсутствие reroll подтверждены.
Бюджет отдельный от parcel H4. Приёмка остаётся открытой до фактических результатов.
После C3 установить OWNER_QA и перейти к следующей готовой задаче, не объявляя весь task DONE.

C4 live evidence: `.artifacts/creepy-c4-085f/01-observation.json`, `02-observation.json` и просмотренные
`01-terminal-skip.png`, `02-carry.png`; case3 `03-observation.json` INCONCLUSIVE, без поворота/PNG.
Case2: QA seed1/native probability0.6, реальный Carry и
движение; ready/deadline/replans/sequence неизменны, эпизод завершён за12.57active seconds,
notice=-1/memories0. Вариативность между opportunities и субъективная внезапность не подтверждены.
Case4: actual mouse detection/TALK/cooldown и native Esc pause подтверждены; save/reload/30s
не доказаны из-за QA seed/reset fixture ошибок. Cases5–7 используют корректный seed до генерации,
variation mismatches0; case6 full can_restore PASS. Очередь/source once подтверждены частично;
case6 не достиг контакта, case7 достиг и обнаружил RV-002. Подробности `04–07-observation.json`
и QA-карточка. Все rendered cases ограничены общим бюджетом8; подготовка не выдаётся за PASS.
