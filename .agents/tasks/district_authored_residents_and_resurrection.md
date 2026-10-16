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

R1a `d143a897bcb0c508de1caa50f3eb4a9835d4723e` reviewed без findings
(BASE `92da28ef275ff4e6331bb171251eb8e5ca9e2c41`). DEF_NpcPerson и pure Rules
проверяют постоянную личность; три native карточки Карга–Дьявол–Скромник prototype=true.
R1b подключает authored_people к existing initial allocation/construction, scene selector
и closed snapshot/preflight. Карточка находится по ID в DEF_District, нового saved record
или второго roster нет; NpcRecord variation/name/home/recipient строго сопоставляются ей.
Sparse IDs резервируют next_person по максимуму, не числу карточек. Авторский состав
не создаёт случайного преемника; return+2 ещё не реализован и принадлежит R2.
Pilot DEF_District с тремя карточками проверен через реальные native тела и disk restore.
Schema 28, native golden/manifest обновлены; старая схема отклоняется с сохранением файла.

R1 остаётся IN_PROGRESS: основной район пока использует прежний profiles initial path;
это временная граница миграции R1c, не принятая постоянная двойная модель жителей.
Нужно перевести live состав/isolated rooms, сохранить отдельно guest/fixture generation.
Chain Devil имеет локальный resident-profile внутри пилотной карточки; глобальный guest
archetype пока не менялся. Полные nine/lost/девятый физический дом и контент Source обязательны.
D2 provider `45cb14b55fddea92bf6d1bbc694c856b24fb2b64` reviewed и native restart CLEAN.
Имена, образы, личные сюжеты и часть tuning не утверждены; прототип не финальный канон R3.

R2 inspected independently during R1a review: O_DistrictLifecycle._prepare_morning вызывает
replace_vacancies; mark_dead не должен освобождать home/ID. NpcRemainsService/C_NpcRemains
сейчас имеют body-lifetime released bool и batch key по body.id; заменить контрактом одной
партии на (person ID, death sequence), сохраняя предметы/память и retained body.

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

Собрать review R1b, исправить принятые findings. Затем R1c: перевести основной authored
состав и rooms на постоянные карточки, удалить генерацию именно live residents, не ломая
guest/isolated fixtures. Проверить native construction/placed merchant, текущий schema round-trip
и отдельный process restart. Потом R2: календарный возврат +2, повторная смерть/добыча,
сохранение памяти/заказов. Отсутствующее утверждённое наполнение R3 остаётся открытым.

## Validation / review

R1a: native authored cards **8/89**, archetype catalog **4/934**, variation **6/360**
PASS/CLEAN; MCP diagnostics 3 scripts checked/empty, static PASS, immutable review PASS.
Логи .artifacts/godot_agent/gut-20261016-{214733220,214625233,214658548}.*.
R1b: authored population **6/74 PASS/CLEAN** (creation, seed/reorder, death without successor,
retained+recreated body disk restore with HP/memory, tamper preflight, old-file preservation).
District snapshot **17/215**, world snapshot **47/642**, native baseline **15/802** PASS/CLEAN.
Логи .artifacts/godot_agent/gut-20261016-{215436864,215443782,215504869,215519055}.*.
Golden generation `215411757` PASS/CLEAN, затем обычный baseline read `215519055` PASS/CLEAN.
Formatter/lint, strict architecture, structure, persistence baseline PASS; staged gate перед commit.
R1b review пока REVIEW_PENDING; весь R1 не COMPLETE/DONE. Rendered **0/8**.

Native ResourceSaver сохранил cards/pilot, но оба offline wrapper **FAIL** после save:
`offlinescript-20261016-{214450592,215150462}.*` сохранены. Первый содержит ECS compile
в editor initialization/shutdown; оба aborted scan и mixed RID/ObjectDB/PagedAllocator shutdown.
Эти процессы не PASS, исключения не расширялись, standalone retention investigation не начато.
Их output отдельно загружен и проверен чистыми native runtime GUT; одноразовые scripts в .artifacts/.
Первый guest fixture GUT 7/8 FAIL (не задан dialogue_path) исправлен до R1a checkpoint.

R1c/process restart/visual и R2 NOT_RUN. R2 обязательные случаи: day 1 → day 3,
повторный callback, две реальные смерти, старые заказы/награды, отсутствующее тело,
гость и защита старого файла. Документный PASS не runtime PASS.

## Owner QA / blockers

Утверждения чисел/имён не подменять автогенерацией. До полного авторского наполнения
и обязательной приёмки задача не DONE; R1/R2 могут быть техническими gates для потребителей.
Rendered QA выполнять в пределах неисчерпанного milestone лимита по последнему указанию владельца; пока0/8. Девятый дом остаётся обязательным, не удалённым scope.
