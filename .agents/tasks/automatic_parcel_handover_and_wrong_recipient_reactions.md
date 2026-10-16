# Выдача посылок — автоматический захват и реакции на чужой заказ

Status: **OWNER_QA**
Technical: **IN_PROGRESS**
Execution order: **20**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/automatic_parcel_handover_and_wrong_recipient_reactions.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Автовыдача со стола и из рук строго <1 м, без F и прицеливания; верный заказ проходит
обычные осмотр/оплату. Все реакции, физическое владение, истинный получатель,
запугивание, огонь, сохранения и защита от повторов остаются обязательными.
Пара npc_id + package_id блокируется на 180 активных секунд. Бугай: 25% присвоение,
иначе 50% бросок; итог 25/37.5/37.5%. Запугивание использует исходные формулы Strength.
Все таблицы и краевые случаи Source входят в приёмку, а не только этот перечень.

## Current

Техническое выполнение M1–M2f и ревью записаны в исходном ТЗ как завершённые.
Последний reviewed TARGET_SHA: `427799387733b0aea057db9e77ff894405307040`.
Исходный BASE_SHA: `6ac1ac6e1ffbb8e8bd43a11b989bb8c8152e5dd9`.
RV-001–RV-006 исправлены; полные source/fix SHA и проверки сохранены в Source.
H4 начат: 5/8 случаев, 1/3 PASS, 2/4 INCONCLUSIVE, 5 приостановлен на H4-QA-001/P2.
Подтверждённый дефект возвращает технический gate в IN_PROGRESS до ремонта и ревью.

## Work packages

| Пакет | Результат / состояние |
| --- | --- |
| H1 | Автовыдача и отказ: M1a/b + M2a/b, выполнено и reviewed. |
| H2 | Физические реакции и фактическое содержимое: M2c/d, выполнено и reviewed. |
| H3 | Присвоение, возврат, запугивание и судьба заказа: M2e/f, выполнено и reviewed. |
| H4 | Разрешено до8 случаев; начато5/8, 1/3 PASS, 2/4 INCONCLUSIVE, 5 требует ремонта ввода. |

Не переделывать H1–H3 ради нового разбиения. Возврат к коду — только по конкретному
дефекту либо изменившемуся контракту; проверять затронутые гарантии, не всю историю.

## Entry points / dependency gates

Использовать владельцев CustomerParcelOffer, штатного handoff, реакций/инцидентов,
GrabService и save-codec, перечисленных в Source. H4 не блокирует независимые задачи.
Согласованность посылок уже завершена: её task в completed не открывать заново.
Код Жуткого и Скромника потребляет общий handoff, не создаёт свой механизм выдачи.

## Next

Закончить H4-QA-001: scoped native проверки → отдельный коммит → read-only exact-SHA review/triage.
Затем продолжить уже начатый случай5 и оставшиеся6–8 из
[QA-карточки](../../.qa/tasks/automatic_parcel_handover_and_wrong_recipient_reactions.md).
Не повторять завершённые случаи2/4 и не заменять их INCONCLUSIVE на PASS.
Повторное разрешение на те же восемь случаев не требуется.

## Validation / review

Импортированная M2f evidence: GUT incidents 44/44, 513 assertions, native parser 1/0,
MCP без ошибок, formatter/architecture/structure PASS; review terminal PASS.
Reviewer execution был NOT_RUN. Это историческая проверка указанного SHA, не нового HEAD.
Перед QA сопоставить тестируемую сборку с reviewed checkpoint; изменённые зависимости
получают только соответствующую перепроверку. Новый запуск в рамках рефакторинга: NOT_RUN.

## Owner QA / blockers

Разрешение от 2026-10-16: до 8 rendered/playtest случаев данной QA-карточки, начато5/8; подробные результаты и пределы evidence в QA-карточке.
Оно не распространяется на другие NPC, произвольные визуальные проверки или новые сценарии.
Holy precedence и абсолютные огненные исходы остаются отмеченными в Source авторскими
defaults с Inspector overrides, не новым подтверждением владельца. DONE/архив — после
полной обязательной приёмки; ожидание H4 не является основанием улучшать готовый код.

## H4-QA-001 / P2 — Carry скрывает фактическое требование

ACCEPTED: при наведении на присвоившего посылку Бугая с занятым Carry штатный resolver
выбирает RELEASE вместо доступного DEF_CustomerParcelDemandAction. Native E отпускает
собственную вещь. Evidence: `.artifacts/parcel-h4-ca63af48/05-input-reproducer.json`.
Native red: `parcel_h4_carry_demand_red2.stdout.log`,12/13 assertions, точное несовпадение действия.
Ремонт: явный readonly opt-in Definition позволяет доступному контекстному Interact
опередить Carry release; включён только для прежнего размещения и parcel demand.
Системы ввода, физическое владение, focus/modal, authored ресурсы/schema не меняются.
Regression использует реальный луч/NPC, занятый Carry, native resolve/execute, modal и
возврат к RELEASE после завершения demand. Ревью ремонта: REVIEW_PENDING до отдельного коммита.

Ремонт native PASS: incidents45/45,538 assertions,stderr0 (`gut-20261016-165419082.*.log`),
grab/input92/92,438 assertions,stderr0 (`gut-20261016-165505401.*.log`),
оба Functional=PASS/diagnostics=CLEAN. MCP5 checked/empty; initial hot reload43 разрешён
свежей path diagnostic/native execution. Formatter5/strict architecture0/structure/diff-check PASS.
Rendered case5 ещё не продолжён. Reviewer execution NOT_RUN; main выполнил native проверки.
