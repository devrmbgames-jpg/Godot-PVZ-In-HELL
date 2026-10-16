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

R1a/R1b provider reviewed: typed DEF_NpcPerson, three prototype cards, explicit ID/home/
recipient/profile/scene, seed/reorder independence, strict retained/fresh/cold restore.
Последний reviewed provider `2c0be0eae47131f0a3b41bcc23f1a5eced4ed015`.
R2a реализован и локально проверен, **review ещё pending**: NpcRecord.deaths хранит
NpcDeathRecord(sequence/day/returned_day), death_day остаётся текущей смертью.
O_DistrictLifecycle вызывает явный return_due при подготовке утра/дискретной смене фазы;
срок вычисляется как death_day + 2, безопасное место проверяется до новой жизни.
Сохраняются то же тело/ID/дом/variation/вещи/старые авторские значения. HealthMutationService
восстанавливает максимум HP только через explicit return; обычный сон не лечит.
C_NpcRemains.released — guard текущей жизни, C_LootDrops — receipts по person/death sequence.
Поздний callback сверяет captured C_Death и World; не может убить вернувшуюся личность.
Native Lost guest preset создан через MCP, без дома; @tool NpcVariation позволяет авторить
его фиксированный preset штатным Resource API. Resident-only и guest cold smokes PASS.
Schema 29/closed codec/native golden согласованы; старые версии отклоняются, файлы сохраняются.

Весь R1/R2 ещё IN_PROGRESS. R2b (знание виновника, память обстоятельств, персональная реакция)
не реализован; голая календарная история не заменяет эти требования. Main/rooms всё ещё
используют profiles path: временная граница R1c, не принятая постоянная dual resident модель.
Lost main сейчас placed merchant; перед guest-переводом нужны семь barter ролей. Девятый
физический дом — provider physical_homes_and_privacy. Полные nine/lost/content/quests R3
обязательны; прототипные имена/образы/сюжеты не объявлены каноном.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| R1 | Авторская identity/home/recipient и пилот; main/rooms integration завершает R1c без live resident generation. |
| R2a | Calendar +2, retained body, повторные смерти/партии, Night retry и save/load/cold restart. |
| R2b | Воспринятый виновник/подозрение/неизвестность, память обстоятельств, персональное социальное продолжение после возврата. |
| R3 | Девять жителей, Lost guest, девятый физический дом, привычки/интересы/желания, личные квесты и все диалоги Source. |

R1/R2 включают собственные closed save/preflight и lifecycle gates. Никакой пакет не отменяет
полный Source; прототип и технические tests не заменяют финальное наполнение/приёмку R3.

## Entry points / dependency gates

NpcRecord/C_District/C_NpcIdentity, district_population_service, placement/day owners,
профили/definitions и существующие death/loot/dialogue/quest boundaries из Source.
[Основа общества](npc_living_society/01_foundation_and_contracts.md) переиспользует R1/R2,
не создаёт второй roster. [Физические дома](npc_living_society/physical_homes_and_privacy.md)
владеют помещениями/дверями/HOME runtime; здесь — постоянная привязка личности к home_id.
API диалогов и социальный граф потребляются по готовности их контрактов; не образовывать
цикл ожидания полного DONE всех соседей. Новый граф не нужен для stable ID в R1.

## Next

Зафиксировать R2a coherent checkpoint, собрать immutable review/triage, исправить принятые
P0/P1/P2. Затем R2b: причина/воспринятый виновник и социальная реакция без телепатии;
существующий observe_damage пропускает C_Death, а обычный can_see требует живого observer.
Использовать текущий O_DistrictLifecycle/captured terminal marker и существующего владельца
NpcRecord/NpcSocial memory; не создавать второй death roster или Service tick.
После verified R2 завершить R1c совместно с barter/physical-home provider contracts,
проверить authored-roster placed merchant и убрать генерацию live residents.
Отсутствующее утверждённое наполнение R3 остаётся открытым.

## Validation / review

R2a текущие native проверки **PASS/CLEAN**, raw .artifacts/godot_agent/:

| Gate | Tests/assertions | gut-20261016 timestamp |
| --- | --- | --- |
| authored life cycle | 16/292 | 225608003 |
| schema29 baseline ordinary read | 15/805 | 224349068 |
| schema29 golden generation | 15/804 | 224324109 |
| district snapshot | 17/215 | 224413815 |
| world snapshot | 47/642 | 224434861 |
| legacy NPC remains | 7/76 | 224449305 |

Life suite: actual damage, days 1→3/7→9, две смерти и разные receipts, прежнее тело,
blocked home/retry, old queued marker, no living-sleep heal, Night I/O retry, tamper rejection,
Lost без дома и старый файл. Базовый World не хранит dormant structural signals; fixture
переведена на production GameWorld и корректно завершает startup/первое утро.
Ранние red logs сохранены: `221457690` (нет loot queue в fixture), `221549423`–`222448955`
(ошибочный active-only lifetime guard и native World fixture), `222819837` (не подготовлено
первое утро fixture). Исправлено до coherent checkpoint, не engine exception/waiver.

Actual **двухпроцессные** smokes PASS; tests/artifacts/, combined logs без errors/warnings:
- npc_guest_life write `20261017-085005957`, restore `20261017-085014061`;
- npc_life_cycle write `20261017-085022215`, restore `20261017-085030281`;
- npc_authored_people write `20261017-085038388`, restore `20261017-085046488`.

Cold life restores день 2/death 1, возвращает в 3, снова убивает/возвращает в 5,
сохраняет ID/дом/scene/clock/HP/visited/quest_stage и две партии. Guest использует отдельный
слот и не получает дом. Это manual snapshot/disk cold smoke; scheduled Night retry проверен GUT.
Formatter/lint, strict architecture, structure, persistence baseline PASS; staged gate перед commit.
R2a **REVIEW_PENDING**, repair **0/2**; rendered **0/8**, Windows QA build этого пакета NOT_RUN.

Принятый R1 RV-001 **FIXED**: production/test `83873c575b0db5cb6684b7ff90cdc6d1085fa0fd`,
точный DEF_NpcPerson read edge `0b86da5ba79f028f62c77d34991472e74956ab95` (structure PASS).
На 83873 structure был FAIL — не считать промежуточный gate успешным.
Re-review BASE `11d735a284aa0b4211608735266ea597c77de338` →
TARGET `0b86da5ba79f028f62c77d34991472e74956ab95`: PASS, cycle **1/2**.
Fix запрещает подмену dynamic scene/alias, оставляет native authored_id owner.
R1 cold-smoke review BASE `0b86da5ba79f028f62c77d34991472e74956ab95` →
TARGET `2c0be0eae47131f0a3b41bcc23f1a5eced4ed015`: PASS, findings нет.
R1a BASE `92da28ef275ff4e6331bb171251eb8e5ca9e2c41` →
TARGET `d143a897bcb0c508de1caa50f3eb4a9835d4723e`: PASS, native cards 8/89.

Старые offline authoring wrappers `offlinescript-20261016-{214450592,215150462}.*` — **FAIL**,
сохранены: первый ECS compile при editor initialization/shutdown, оба aborted scan и mixed
RID/ObjectDB/PagedAllocator shutdown. Output отдельно проверен CLEAN GUT, исключения не
расширялись, standalone retention investigation не начато. Новые Guest assets/scenes — live MCP.
R1c/authored placed merchant, R2b/social reactions, полный R3 и visual acceptance NOT_RUN.

## Owner QA / blockers

Утверждения чисел/имён не подменять автогенерацией. До полного авторского наполнения
и обязательной приёмки задача не DONE; R1/R2 могут быть техническими gates для потребителей.
Rendered QA выполнять в пределах неисчерпанного milestone лимита по последнему указанию владельца; пока0/8. Девятый дом остаётся обязательным, не удалённым scope.
