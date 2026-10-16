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
Последний reviewed provider `5deafb36b509cb675f5144e4201c828e8fd5d9f0`.
R2a reviewed: calendar +2, retained body, separate per-death loot receipts, stale callback
identity, blocked-space retry, Night write retry и strict restore. R2b реализован и проверен,
**REVIEW_PENDING**: NpcDeathRecord хранит actual actor/type/position отдельно от known/suspected
actor, выбранную реакцию и два once guards. Источник фактического урона не обвиняет скрытое
лицо. Exact terminal C_Death снимает собственное знание до cleanup по общему LOS/FOV/light.
Первая уместная добровольная беседа street/service использует общий npc_return.dialogue;
только показанная строка подтверждает response_given, cancelled async read не считается показом.
Авторский idle BT subtree запрашивает разовую реакцию после возврата; бой/опасность/роли выше,
NPC-нападение сохраняет разрешение профиля, риск и ambient limit. После конца поиска эпизод
не запускает месть снова. NpcRecord.deaths — один владелец истории, UI хранит лишь borrowed номер.
Schema30/codec/preflight/native golden согласованы; старые файлы отклоняются и сохраняются.
Native MCP diagnostics по фактическим script paths CLEAN; transient anonymous reload43
не выдаётся за ошибку runtime и не объявляется PASS без отдельной native проверки.

Весь R1/R2 ещё IN_PROGRESS: R2c (реальные вещи/выплаты/принятые обещания и их сроки) открыт.
Main/rooms всё ещё
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
| R2c | Сохранённые реальные вещи/выплаты/заказы, перенос личных сроков во время отсутствия; Source §§6–7. |
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

Зафиксировать R2b coherent checkpoint; review exact BASE
`5deafb36b509cb675f5144e4201c828e8fd5d9f0` → новый TARGET, triage/fix P0/P1/P2.
Пока pending — только независимый анализ Source §§6–7 и действующих owners обещаний/вещей.
Затем R2c: source-required перенос личных сроков при временной смерти, реальные сохранённые
предметы/деньги/заказы и отсутствие повторной награды. Без нового roster/Service tick.
После verified R2 завершить R1c совместно с barter/physical-home provider contracts,
проверить authored-roster placed merchant и убрать генерацию live residents.
Отсутствующее утверждённое наполнение R3 остаётся открытым.

## Validation / review

R2b текущие actual native gates **PASS/CLEAN**, .artifacts/godot_agent/:

| Gate | Tests/assertions | gut-20261016 timestamp |
| --- | --- | --- |
| death knowledge + real terminal/calendar + native BT + street panel | 25/464 | 232016876 |
| real service return + existing dialogue memory/variants/delivery | 41/812 | 232356332 |
| common geometry/FOV/light/hearing | 8/27 | 232211292 |
| existing grudge/ranged contracts | 16/153 | 232248961 |
| schema30 ordinary golden read | 15/805 | 232145738 |
| schema30 native golden generation | 15/804 | 232110354 |

Knowledge suite: actual recognized player/NPC, wall-hidden source, prior-seen suspicion,
environment without blame, non-grudge memory, retained-body disk restore, all missing record
fields/unknown actor rejection, native authored reaction leaf/ambient budget, finite pursuit,
first actual panel line/reopen, cancelled read and no changed visit outcome. Prototype opt-in
NPC conflict fixture changes only its detached test profile, not authored production cards.
MCP reimport npc_return.dialogue PASS; path diagnostics 14 selected scripts CLEAN. Formatter/
lint, strict architecture, structure, persistence baseline PASS; staged gate before commit.
Raw earlier red logs retained: `231222480` (nonpersistable test player, Fire-resistant target,
new dialogue not yet imported), `231309416` (test profile prohibited conflict), `232338405`
(test used nonexistent enum constant). Fixture/API/import corrections preceded this checkpoint.

Schema30 **two-process** smokes PASS, tests/artifacts/ combined logs:
- npc_life_cycle write `20261017-092428846`, restore `20261017-092436956`;
- npc_guest_life write `20261017-092445067`, restore `20261017-092453164`.
They prove nondefault own-death position/pending response across process exit, environment
without invented blame, days 1→3→5, two distinct batches, same body/identity/old author memory.
Known-player disk restore and actual presentation are GUT evidence, not claimed cold/rendered QA.
First smoke launch without explicit -GodotPath failed before engine start because runner reads
JSONC as JSON; explicit verified .bin Godot console path succeeded. Runner scope not expanded.
R2b **REVIEW_PENDING**, repair **0/2**; rendered **0/8**, Windows build for this internal step NOT_RUN.

R2a review BASE `2c0be0eae47131f0a3b41bcc23f1a5eced4ed015` →
TARGET `30e6716aa696311581cd1be4145dbd1466d080cd`: два P2 приняты.
RV-002 **FIXED** exact NpcDeathRecord.SAVE_FIELDS; RV-003 **FIXED** pending authored body
requires death=true/enabled=false. Fix `5deafb36b509cb675f5144e4201c828e8fd5d9f0`;
red `gut-20261016-230318246` reproduced six corruptions; green `230350002` 16/310 CLEAN.
Targeted re-review BASE `30e6716aa696311581cd1be4145dbd1466d080cd` →
TARGET `5deafb36b509cb675f5144e4201c828e8fd5d9f0`: PASS, cycle **1/2**, no new findings.
R2a prior golden/district/world/remains PASS at `224349068`, `224413815`, `224434861`,
`224449305`; new schema consumers use current results above. Old anonymous reload43 was
independently checked CLEAN by native path diagnostics and Godot CLI, not waived.

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
R1c/authored placed merchant, R2c/full obligations, полный R3 и visual acceptance NOT_RUN.

## Owner QA / blockers

Утверждения чисел/имён не подменять автогенерацией. До полного авторского наполнения
и обязательной приёмки задача не DONE; R1/R2 могут быть техническими gates для потребителей.
Rendered QA выполнять в пределах неисчерпанного milestone лимита по последнему указанию владельца; пока0/8. Девятый дом остаётся обязательным, не удалённым scope.
