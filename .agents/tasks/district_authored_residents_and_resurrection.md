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

R1 начат: проверены NpcPopulationRules.initial_records, NpcVariationRules,
NpcRecord/C_District, construction/bind и DistrictSnapshotRules. Runtime пока не менялся.
Сейчас resident ID/home/portal зависят от порядка profiles/places, variation — от seed;
это конкретная заменяемая поверхность. Данные остаются в существующем C_District.people,
живое тело связывается прежним C_NpcIdentity, materialization/Brain ownership сохраняется.
D2 provider `45cb14b55fddea92bf6d1bbc694c856b24fb2b64` reviewed, native tests+restart CLEAN;
его общий task closure не нужен для авторских параметров R1.
R1 boundary: typed editable resident card с явными npc_id/home/recipient/profile/scene
и фиксированной personal variation; три явно прототипные карточки Карга–Дьявол–Скромник.
Seed/порядок массива не выбирают личность; guests остаются отдельным входом.
Применить через existing initial roster/construction/closed codec, без второго реестра.
Смерть/return+2/loot принадлежат R2, полный nine/lost/content — R3, scope Source сохранён.
Авторские имена, образы, личные сюжеты и часть tuning ещё не утверждены.
Их отсутствие не блокирует технические R1/R2: использовать явно отмеченные тестовые
карточки/черновики, не объявляя их каноном или финальной приёмкой R3.

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

Реализовать R1 единым пакетом: authored resident type/три prototype .tres,
initial allocation и строгий current-schema preflight/retained+fresh restore;
проверить reorder/seed independence и guest separation. При изменении saved fields
повысить фактическую schema и обновить native golden; старые файлы сохранить. Затем R2; незаполненные авторские поля R3 собрать
в конкретный перечень, продолжая независимые технические задачи.

## Validation / review

Новые gameplay/parser/GUT/review NOT_RUN. Проверить day 1 → day 3, повторный death callback,
две реальные смерти, существующие заказы/награды, отсутствующее тело, свежую загрузку,
гостя и защиту старого файла. Документный PASS прошлого плана не равен runtime PASS.

## Owner QA / blockers

Утверждения чисел/имён не подменять автогенерацией. До полного авторского наполнения
и обязательной приёмки задача не DONE; R1/R2 могут быть техническими gates для потребителей.
Rendered QA выполнять в пределах неисчерпанного milestone лимита по последнему указанию владельца; пока0/8. Девятый дом остаётся обязательным, не удалённым scope.
