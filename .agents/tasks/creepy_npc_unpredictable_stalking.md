# Жуткий — скрытное сближение и сервисный контакт

Status: **IN_PROGRESS**
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
На текущем HEAD runtime/tests совпадают с этим snapshot; после resume исправлен только
перенос длинного комментария CustomerVisit. Повтор всей принятой матрицы не требуется.
Review BASE: `e45ca4d8251ffc43fdce1ab111a8afc32ac85722`; TARGET — closing checkpoint pending commit.
C3 ещё IN_PROGRESS: независимое review/triage открыто, общий structure gate пока FAIL
из-за старого task-layout validator после owner task refactor; это отдельный compatibility fix.

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
| C3 | Закончить существующий M3b целиком: rear SERVICE → arrive → обнаружение/номер → handoff/осмотр → сохранение/загрузка. IN_PROGRESS. |
| C4 | Обязательная отдельная игровая приёмка Жуткого. NOT_RUN. |

C3 — один согласованный пакет реализации/проверок/ревью, не отдельное ревью каждого
поля schema или leaf. Не добавлять новые хоррор-механики и не переписывать C1/C2 без дефекта.

## Entry points / dependency gates

Начать с NpcServiceRole/CustomerVisit, сервисных bindings/sensor и bt_npc_service,
затем перечисленных в Source NpcStalkingService/Queries/Rules и тестов service/queue/stalking.
Customers владеет визитом/живым контактом; NpcRecord — личной историей/паузы через свой Service.
C3 использует технически принятый [общий handoff](automatic_parcel_handover_and_wrong_recipient_reactions.md);
его отдельная субъективная QA не блокирует интеграцию. Не ждать полного DONE соседей.

## Next

Закоммитить closing C3 checkpoint и получить immutable review/triage по указанному BASE.
Параллельно исправить независимый validator compatibility gate; затем техническое закрытие C3,
OWNER_QA для C4 и следующий готовый пакет. Разрешённую H4 parcel QA выполнить в её8 случаях.
Не запускать rendered C4 без task-specific разрешения и не объявлять всю задачу DONE.

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
Formatter26/strict architecture0/persistence inventory PASS. Structure — FAIL: все новые root
карточки отвергнуты старым проверяющим layout; scoped compatibility correction pending.
Comment-only MCP hot reload initially returned43; subsequent native path diagnostic checked/empty,
а свежий native parser PASS. Эти transient diagnostics не классифицировались как shutdown.
C3 immutable review: REVIEW_PENDING, repair0/2. Rendered C4: NOT_RUN,0/8.

## Owner QA / blockers

Разрешение на восемь случаев автовыдачи не является разрешением C4. Игровая приёмка
Жуткого остаётся открытой до task-specific разрешения; техническую работу продолжать.
После C3 установить OWNER_QA и перейти к следующей готовой задаче, не объявляя весь task DONE.
