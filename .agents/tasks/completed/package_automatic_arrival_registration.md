# Посылки — автоматическая регистрация при поступлении на выгрузку

Status: **DONE**
BASE_SHA: `764486919409df4bf053d04efed2346c71799b4f`
TARGET_SHA: `76bd92013fd8792a683967dfbf02752f002e58b9`

Связанный этап: [утренняя машина](district_morning_truck.md).
Требование повторно указано владельцем 2026-10-15. Выполнение авторизовано текущей командой `/goal` о задачах `.agents/tasks`; прежняя пометка об ожидании команды относилась к исходному baseline `6aac58da7f03943aa62614ee3dbb1ad317747748`.

## Task state

### Goal

Требование владельца:

> Когда товар приходит на выгрузку — ему номер и регистрация назначается АВТОМАТИЧЕСКИ!
> Сканер нужен теперь, чтобы игрок мог понять, какой номер у посылки.

### Constraints / acceptance

- [x] При появлении реальной входящей коробки на выгрузке ей автоматически назначаются
  регистрация и свободный номер. Взять сканер или вынести коробку для этого не требуется.
- [x] В журнале и терминале сразу отражаются номер, дата поступления и дата регистрации.
- [x] Сканер показывает существующий номер; первое и повторное чтение не выделяют новый
  номер, не меняют регистрацию или её дату и не создают вторую запись.
- [x] Отсутствие сканирования не препятствует приходу получателя и выдаче и не вызывает
  штраф за несвоевременную регистрацию.
- [x] Занятое место выгрузки не создаёт фиктивную регистрацию ещё не появившейся коробки.
  Повторы поставки не создают дубликаты коробок, записей или номеров.
- [x] Номера поступивших коробок сохраняются через сон и загрузку. Освобождение номера
  сохраняет существующий контракт подтверждённого ухода со склада.
- [x] Учитывается совместимость с уже сохранёнными незарегистрированными посылками:
  необходимое поведение определить до изменения загрузки или версии сохранения.
- [x] Обновлены прямые регрессии и ручные чеклисты, закрепляющие старое поведение.

### Current

Implementation завершён и прошёл независимое read-only review по указанным BASE_SHA/TARGET_SHA.
Замечаний P0/P1/P2 нет; triage завершён без требуемых исправлений. Receiving после успешного native
placement вызывает единственный allocator PackageRegistrationService с отложенной публикацией,
фиксирует manifest/last_spawn_tick и создаёт visit перед регистрационным фактом. Callback может
повторно вызвать доставку или изменить pending без повторного появления текущей коробки.

scan() проверяет настоящий хват/ray/access, читает номер и фиксирует только Scan.SCANNED;
REGISTERED/дата/ledger/registration event не меняются. Доверенный register_package не имитирует scan.

Совместимость определена до изменения restore: поддерживаемая schema19/PVZH1 и closed fields
сохранены. После snapshot overlay, под reaction suppression и до readiness/Customers planning,
package-owned reconcile_received регистрирует участвующие реальные коробки active arrivals без
номера. Порядок ledger детерминирован; дата регистрации — восстановленное текущее утро, received_day
сохраняется. Существующие номера/даты не меняются; отсутствующие/закрытые/LOST коробки не создаются.
События регистрации не replay, уже принятые штрафы не отменяются. Новый persistence→packages edge
явно ограничен методом reconcile_received и одним WorldSnapshotService в domain_contracts.json.

Прямые regressions и headless receiving_scan smoke обновлены. Профильные controls/Customers/
persistence/architecture/receiving docs и ручные чеклисты отражают новый контракт; прежняя общая
ручная приёмка не выдаётся за новую. Старый withdrawn patch не применялся и не является evidence.

### Next

Обязательные implementation, verification и review gates завершены. Дополнительные ручные
сценарии остаются в профильных QA checklists с фактическим статусом NOT_RUN.

### Validation

- PASS: focused GUT103/103,1018 assertions: morning_truck15/110 (`gut-20261015-233224322`),
  package_receipts_loss15/154 (`233835096`), world_snapshot38/480 (`233302317`),
  package_scan_readonly2/27 (`233358290`), customer_flow27/201 (`233951989`),
  package_return6/46 (`234030989`); полные логи `.artifacts/godot_agent/gut-20261015-*.{stdout,stderr}.log`.
- PASS: formatter11 scripts; native ParseChanged11/0, exit0/stderr empty,
  `parsechanged-20261015-234125658`; MCP11 paths checked/empty после исправления UI fixture,
  scripts_instantiated=0. Final smoke native/MCP PASS, parser `parsefiles-20261015-234500117`.
- PASS: incremental role validator6 production paths, strict architecture0 lexical findings,
  project structure и persistence baseline. Dependency contract объявляет только owning restore API.
- PASS: receiving_scan headless main-level smoke (реальные коробки/ввод/терминал/сон/второе утро),
  `tests/artifacts/receiving_scan-20261016-094337584.log`, exit0, explicit PASS line, без новых ошибок.
  Предыдущий FAIL был stale legacy-content icon assumption; fixture исправлен по текущему catalog
  manifest, gameplay для этого не менялся. Captures/rendered QA не запускались.
- Ручная игровая/визуальная приёмка: **NOT_RUN**,0/8; визуальное качество не заявляется.
- PASS: независимый reviewer проверил immutable diff BASE_SHA → TARGET_SHA; material findings
  отсутствуют, architecture/style PASS. Reviewer не запускал проверки (VALIDATION NOT_RUN);
  результаты локальных проверок выше принадлежат Main.

### Owner QA / blockers

Implementation review **PASS**, triage завершён; незакрытых обязательных blockers нет. Новые ручные
сценарии отмечены NOT_RUN в профильных QA checklists, прежнее общее ACCEPTED не переносится на
новый контракт. Acceptance этой задачи требует обновить чеклисты, а не объявить их ручное прохождение.
