# Постоянные жители — личности, возвращение и авторское наполнение

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **70**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/district_authored_residents_and_resurrection.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Девять постоянных авторских жителей, включая Вампира, и возвращающийся гость Потерянный.
Личность/дом/память не пересоздаются вместе с телом. return_day = death_day + 2;
добыча однократна для каждой действительной смерти. Новая кампания, без миграции и
перезаписи старых файлов. Все личные привычки, квесты, диалоги и последствия Source обязательны.

## Current

R1a реализован как изолированный контракт авторской личности: DEF_NpcPerson
(key = постоянный npc/N, profile/scene/variation/recipient/home/entry/exit) и
NpcAuthoredPersonRules (атомарная проверка набора, detached allocation, immutable match).
Три native .tres Карга–Цепной дьявол–Скромник явно prototype=true; имена не объявлены каноном.
Chain Devil использует локальный resident-profile внутри пилотной карточки: действующий
visitor archetype ещё не изменён. Получатели/дома заданы явно, общий район пока не переключён.
Авторское имя допускается вне RNG-пула; совместимость выделена в valid_selection,
прежний generated API сохраняет проверку seed/имён. C_District.people остаётся владельцем
записей, C_NpcIdentity — связи тела; второго roster нет.

R1a не завершает R1: live initial roster/construction/scene selector, closed snapshot/
current schema и retained+fresh restore ещё используют прежний контракт. Переключить их
следующим согласованным пакетом; постоянную двойную resident-модель не оставлять.
D2 provider `45cb14b55fddea92bf6d1bbc694c856b24fb2b64` reviewed, native tests+restart CLEAN.
Предыдущий docs review BASE `89b2611097648fb4eb4d3a504b2323b42fcd4f66` →
TARGET `92da28ef275ff4e6331bb171251eb8e5ca9e2c41`: PASS, findings нет.
Смерть/return+2/loot принадлежат R2, полный nine/lost/content — R3, scope Source сохранён.
Авторские имена, образы, личные сюжеты и часть tuning ещё не утверждены; R1/R2 разрешены
на явно прототипных данных без объявления канона и финальной приёмки R3.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| R1 | Устойчивая авторская личность/дом/recipient identity и пилот Карга–Дьявол–Скромник; новая игра/загрузка не генерируют новую личность. |
| R2 | Смерть, временное отсутствие, return_day, память/обязательства и однократная добыча продолжаются через save-load. |
| R3 | Полный девятичленный состав, Потерянный, девятое домашнее место, привычки, личные квесты и диалоговая обратная связь из полного ТЗ. |

R1/R2 включают необходимые codec/tests. Не откладывать правильность загрузки до R3.
R3 не сокращать до голых ресурсов с именами; неподтверждённое авторское наполнение остаётся открытым.

## Entry points / dependency gates

NpcRecord/C_District/C_NpcIdentity, district_population_service, placement/day owners,
профили/definitions и существующие death/loot/dialogue/quest boundaries из Source.
[Основа общества](npc_living_society/01_foundation_and_contracts.md) переиспользует R1/R2,
не создаёт второй roster. [Физические дома](npc_living_society/physical_homes_and_privacy.md)
владеют помещениями/дверями/HOME runtime; здесь — постоянная привязка личности к home_id.
API диалогов и социальный граф потребляются по готовности их контрактов; не образовывать
цикл ожидания полного DONE всех соседей. Новый граф не нужен для stable ID в R1.

## Next

После review R1a переключить existing initial allocation/construction/scene selector и
closed codec/preflight на authored residents; проверить seed/reorder independence,
guest separation, retained+fresh restore и защиту старого файла. При новых saved fields
повысить фактическую schema и обновить native golden. Replacement-ветка и
смерть/return+2/loot — R2; не объявлять R1 закрытым до его save/load checks.
Недостающие авторские поля R3 собрать в конкретный перечень, продолжая независимую работу.

## Validation / review

R1a native GUT: authored people **8/89 PASS/CLEAN**, archetype catalog **4/934 PASS/CLEAN**,
variation regression **6/360 PASS/CLEAN**. Логи .artifacts/godot_agent/:
`gut-20261016-214733220.*`, `gut-20261016-214625233.*`, `gut-20261016-214658548.*`.
MCP diagnostics трёх production scripts: checked, пусто. Formatter/lint, strict architecture,
structure PASS; staged validation и review перед commit. Rendered **0/8**.
Первый guest fixture пропустил обязательный dialogue_path: GUT 7/8 FAIL; исправлено.
Первичный MCP compile до filesystem scan не видел новый global class; итоговый checked CLEAN.
Native ResourceSaver сохранил три карточки, но offline wrapper **FAIL** после save:
`offlinescript-20261016-214450592.*` содержит ECS compile error в editor initialization/shutdown,
aborted scan и mixed shutdown diagnostics. Этот запуск не PASS. Сохранённые карточки отдельно
загружены/проверены чистым native GUT; одноразовый authoring script в .artifacts/.

R1b save/load/runtime/visual NOT_RUN. R2 проверки: day 1 → day 3, повторный death callback,
две реальные смерти, существующие заказы/награды, отсутствующее тело, свежая загрузка,
гость и защита старого файла. Документный PASS не runtime PASS.

## Owner QA / blockers

Утверждения чисел/имён не подменять автогенерацией. До полного авторского наполнения
и обязательной приёмки задача не DONE; R1/R2 могут быть техническими gates для потребителей.
Rendered QA выполнять в пределах неисчерпанного milestone лимита по последнему указанию владельца; пока0/8. Девятый дом остаётся обязательным, не удалённым scope.
