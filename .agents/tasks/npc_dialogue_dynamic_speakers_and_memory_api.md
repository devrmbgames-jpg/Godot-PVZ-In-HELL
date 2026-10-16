# Диалоги — динамический говорящий и пять операций памяти

Status: **OWNER_QA**
Technical: **COMPLETE**
Execution order: **60**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ](references/task-refactor-2026-10-17/npc_dialogue_dynamic_speakers_and_memory_api.md.txt).

Полный объём требований сохранён в Source; эта карточка владеет Current/Next и evidence.
Правила автономного продолжения — в [README](README.md).

## Goal / acceptance

Актуальное имя личности в street/service; русские комментарии общего ctx с точной
семантикой holds_grudge. Ровно пять новых операций: set_tag, get_tag, set_val,
get_val(value_name), add_val. Отсутствие читается без записи; null остаётся явным
значением; числовое сложение не принимает bool/нечисловые данные.
Параметры принадлежат NpcRecord/npc_id, переживают роль/день/сон/пересоздание/save-load,
не перетекают к соседу. Непредставимые persistent значения отклоняются до замены файла.
Авторские коллекции не заменяют деньги, HP, quests, typed-отношения или NpcMemory.
Закрытый ctx не пишет; технический повтор advance не выполняет mutation дважды.
Обязательные ручные UI проверки остаются отдельным gate.

## Current

D1 reviewed PASS: общий speaker_name читает личность, legacy customer — авторское имя;
sn сохранён. 246 NPC headers в21 ресурсе используют native подстановки Dialogue Manager.
Две Angel-таблички и все cues/choices/tags/условия сохранены.
D1 review BASE `41243ae7956505d6fceb008500e84403fc2b220a`,
TARGET `f7dd1812540e9bfbba0bfdb7d95341743b188b44`: no findings.
Русские комментарии общего ctx reviewed в
`6665e0dc26a76f58b3e2b4e88146c2b487475f1c`
от BASE `23e26a2541dab773a2a4db3cdc29e234c7ce657b`; executable lines не менялись.

D2 реализован: NpcRecord.dialogue_tags/dialogue_values, один writer
NpcDialogueMemoryService, пять thin ctx adapters. Закрытые/непривязанные ctx не создают
личность или ключи. Панель сохраняет существующий guard до await; реальный async-тест
проверяет технический повтор и поздний возврат после закрытия.
SaveDataCodec явно кодирует обе коллекции через DialogueValueCodec: reserved keys —
данные, typed builtin containers сохраняются, Object/RID/Callable/Signal и циклы дают
invalid с путём к ключу. S_NightSave сообщает причину preflight и сохраняет прежний файл.
Схема27, native golden и inventory обновлены; прежние схемы отклоняются/файл сохраняется.
PVZH1 и DEFERRED ConfigFile B01 не менялись.
D3 авторская документация/пример в [docs/dialogue_memory.md](../../docs/dialogue_memory.md)
компилируется/исполняется native DMCompiler/runtime; пример денег предполагает
подтверждённую передачу, не выполняет списание и не вводит cost_mone.

D2/D3 checkpoint `45cb14b55fddea92bf6d1bbc694c856b24fb2b64`
reviewed от BASE `4c91c7137806be85cddb42059a38d144397d5bb6`: no material findings,
ARCHITECTURE/STYLE PASS; reviewer execution NOT_RUN. Triage: принятых P0/P1/P2 нет.
Technical COMPLETE. Rendered UI acceptance **3/3 PASS**, использовано3/8,
[QA card](../../.qa/tasks/npc_dialogue_dynamic_speakers_and_memory_api.md).
Street/service actual имя, focus и authored choices подтверждены; новый ctx помнит visited,
закрытый ctx не пишет; Angel показывает native sign без panel/modal.
Завершающее review и Windows artifact ещё открыты; задача не DONE.

## Work packages / boundaries

| Пакет | Результат |
| --- | --- |
| D1 | Динамические NPC headers и сохранённые player/narrator/sign cues — reviewed. |
| D2 | Единая постоянная память, пять операций, codec/preflight/schema, retained/fresh restore — reviewed PASS. |
| D3 | Русская документация/compiled examples готовы; rendered UI3/3 PASS. |

[Постоянные жители](district_authored_residents_and_resurrection.md) используют проверенный D2,
не требуют заранее готового личного канона. holds_grudge читает существующий NpcGrudgeRules;
авторский одноимённый тег не меняет социальную память.

## Validation / review

Native `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/<suite>.gd`;
логи `.artifacts/godot_agent/gut-20261016-<timestamp>.*.log`.
Текущие проверки ниже реально выполнены: **PASS/CLEAN**, stderr0.

| Suite | Tests/assertions | Timestamp |
| --- | --- | --- |
| dialogue_value_codec: все data Variant, typed/wildcard containers, reserved keys, cycles/runtime rejection | 6/151 | 205945159 |
| npc_dialogue_memory: 34 inherited role/branch checks +6 memory/compiled/await cases | 40/804 | 210704532 |
| npc_dialogue_memory_snapshot: retained/fresh disk, malformed data, Night rejection, previous schema | 11/114 | 210703088 |
| refactoring_v2_persistence_baseline: actual golden read, retained/fresh grips/time/history | 15/802 | 210702143 |
| world_snapshot | 47/642 | 210703156 |
| district_snapshot | 17/215 | 210702885 |
| customer_dialogue | 16/275 | 210806812 |

Hag regression **PASS/CLEAN**,41/1071, timestamp210804729, stderr0.
Two-process native `run_smoke -Name night_persistence` **PASS**:
`tests/artifacts/night_persistence-write-20261017-070554707.log`,
`tests/artifacts/night_persistence-restore-20261017-070608878.log`.
Проверяет новую игру с пустыми коллекциями, Night и реальный restart с null/typed values
и независимыми счётчиками двух NPC. Это не rendered QA.
Formatter/lint13, architecture(strict), project structure, persistence baseline PASS.
Staged agent validator и diff-check PASS; read-only review collected PASS.
Ранние красные fixture-прогоны сохранены, не считаются приёмкой. Full snapshot tests
используют реальный district fixture; dialogue-only fixture имеет inline duplicated Definition.
Старый baseline assertion RigidBody исправлен на текущий CharacterBody контракт.

D1 отдельные native Angel46/850 (202305258) и parcel-incidents48/614 (202317604)
проходили до D2; эти suites на D2 не повторялись. Их результат не объявляется новым PASS.
D1 Import wrapper FAIL из-за mixed shutdown diagnostics сохранён; accepted D1 compiler/GUT
имеют отдельную CLEAN evidence. Никакого расширения engine exception policy нет.

## Next

Собрать Windows QA artifact на reviewed source; собрать docs/QA review по точным SHAs.
После PASS/triage и готового artifact завершить/архивировать эту карточку с исправлением
входящих ссылок, затем продолжить district_authored_residents_and_resurrection (order70).
NPC CharacterBody остаётся OWNER_QA с3 PASS/3 INCONCLUSIVE и исчерпанным6/6.
Не объявлять milestone DONE при pending review или открытой обязательной приёмке.
## Owner QA / blockers

Владелец 2026-10-17 разрешил дальнейшие проверки без повторных вопросов при
неисчерпанном соответствующем лимите; максимум8 на milestone, уже меньшие лимиты сохранены.
Dialogue UI acceptance выполнена; оставшиеся gates — review и Windows artifact.
Имена/реплики примеров не становятся каноном; addon/панель не заменяются.
