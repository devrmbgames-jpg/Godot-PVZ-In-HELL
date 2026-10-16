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
H4 начат: 5/8 случаев, 1/3 PASS, 2/4 INCONCLUSIVE, 5 приостановлен до H4-D01 review.
H4-QA-001 исправлен/reviewed, затем владелец уточнил обязательный dialogue-only UX.
Текущий технический gate IN_PROGRESS: перенос требования в диалог до продолжения H4.

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

Завершить H4-D01: dialog-only migration → native gates → отдельный коммит → exact-SHA review/triage.
После этого продолжить уже начатый случай5 и оставшиеся6–8 из
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

## Current repair / H4-D01

Владелец 2026-10-17: «Эй, это не твоя посылка» — ответ в диалоговой системе,
не отдельное интерактивное действие. Это решение уточняет Source/UI acceptance.
Штатное Поговорить открывает authored Dialogue Manager branch; контекст читает фактический
инцидент. Выбор ответа закрывает modal, повторно проверяет тот же incident/роль/участников
и вызывает прежний CustomerParcelDemandService. RETURN/ATTACK, RNG, ownership, save schema26
и истинный получатель остаются у прежних владельцев. Отмена/начало/конец разговора не
меняют service phase/elapsed и не продлевают окно. Pending RETURN предлагает Забрать посылку.
Native Interact demand и Carry opt-in удаляются целиком; обычное Carry release/placement прежние.
Каноническая авторская ветка: `content/domains/customers/dialogue/customer_parcel_demand.dialogue`.
Ремонт H4-QA-001 исторически reviewed: BASE `a2fc9dce7c7a66077b6c3c4bf30f08d8075b70c4`,
TARGET `823faf152b67ce30ae682aac38a4c37f76664a26`, PASS/no findings; новый UX supersedes этот opt-in.
Исходный runtime repro: `.artifacts/parcel-h4-ca63af48/05-input-reproducer.json`;
исходный red `parcel_h4_carry_demand_red2.stdout.log`,12/13 assertions.
Новые regression checks: реальный ray/USE/Carry → UI response; cancel, modal closure before
ATTACK/RETURN, pending claim/codec without reroll, departure clock, stale Component rejection.
Финальная native проверка48/48,614 assertions,stderr0 (`gut-20261016-171241352.*.log`);
обычный customer_dialogue15/15,272 assertions,stderr0 (`gut-20261016-171100325.*.log`).
Финальные lifecycle guards включены в этот запуск. Review: REVIEW_PENDING до отдельного коммита.
MCP8 checked/empty; formatter8/strict architecture0/structure PASS. Domain edges объявлены явно.
H4 case5 в продолжении, не PASS; попытка подготовки с ошибочным QA-only API остановлена.
Новых завершённых rendered случаев нет: 5/8 started, C4 0/8. Не повторять2/4.
