# Диалоги — динамический говорящий и пять операций памяти

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **60**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/npc_dialogue_dynamic_speakers_and_memory_api.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Имя говорящего берётся из актуальной личности street/service. Комментарии общего ctx —
на русском, включая точное объяснение holds_grudge(). Ровно пять новых операций:
set_tag, get_tag, set_val, get_val(value_name), add_val; get_val отсутствующего ключа
возвращает null без записи, add_val только числовой. Полный Variant/codec и lifecycle
контракт Source сохраняется, включая запрет тихой потери непредставимых значений.

## Current

Документационная часть D3 reviewed PASS на `6665e0dc26a76f58b3e2b4e88146c2b487475f1c`
от BASE `23e26a2541dab773a2a4db3cdc29e234c7ce657b`: русские комментарии/регионы общего ctx,
точная семантика holds_grudge, исполняемые строки не менялись. Reviewer execution NOT_RUN.
D1 реализован: общий read-only speaker_name разрешает имя NpcRecord,
service legacy fallback читает DEF_Customer.display_name. Street sn сохранён; закрытый ctx
возвращает пустое имя. Специальный parcel-demand context использует того же собеседника.
246 статических NPC-заголовков в 21 ресурсе заменены native Dialogue Manager подстановкой;
две Angel-таблички, реплики/choices/cues/tags/условия сохранены. UI/аддон не менялись.
Native imports обновлены, focused GUT прошли; D1 review REVIEW_PENDING. D2 не начат.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| D1 | Общий read-only speaker_name и миграция только NPC-заголовков; реплики игрока/рассказчика, cues и sign mode сохранены. |
| D2 | Пять операций, единый writer в NpcRecord, codec/preflight и fresh/retained restore; два NPC не делят память. |
| D3 | Русская документация ctx, holds_grudge и авторские примеры, скомпилированные установленным Dialogue Manager; интеграционная приёмка. |

Перевод комментариев новых методов делается сразу в D2, не откладывает понятность API.
D3 закрывает оставшийся файл и примеры, не создаёт ещё один API для каждого флага.

## Entry points / dependency gates

content/ui/npc_dialogue_context.gd, npc_street_dialogue_context.gd,
customer_dialogue_panel.gd, NpcRecord/SAVE_FIELDS и существующие archetype .dialogue.
D1/D2 не ждут полной новой агрессии: holds_grudge читает действующий NpcGrudgeRules.
Авторские tags/values не заменяют typed-граф отношений, HP, деньги, quests или NpcMemory.
[Постоянные жители](district_authored_residents_and_resurrection.md) переиспользуют D2,
но не требуют заранее законченных персональных сюжетов для самого API.

## Next

Пройти exact-SHA read-only review/triage D1 checkpoint; затем D2 целиком:
владелец NpcRecord, пять адаптеров, closed ctx/repeated callback, codec/preflight/schema и
fresh/retained roundtrip. Непредставимые persistent значения отклонять до замены save.
Не считать завершённой всю задачу или интеграционную часть D3 до её обязательной приёмки.

## Validation / review

Перевод комментариев: native MCP checked/empty, formatter/lint, executable-line equivalence,
diff-check PASS; runtime для docs-only не запускался. D1: MCP7 checked/empty, formatter/lint7,
architecture(strict), structure PASS. Native DMCompiler компилирует 23 реальных источника;
два source imports зарегистрированы через public DMCache.add_file для headless fixture.
GUT logs: `.artifacts/godot_agent/gut-20261016-<timestamp>.*.log`, все ниже PASS/CLEAN, stderr0:

| Suite | Tests/assertions | Timestamp |
| --- | --- | --- |
| npc_dialogue_variants (две личности, street/service, текущая смена имени, compile23) | 34/726 | 202208405 |
| customer_dialogue (legacy имя, закрытый ctx, modal/lifecycle/tags) | 16/275 | 202220445 |
| npc_angel_dialogue (режим таблички и lifecycle) | 46/850 | 202305258 |
| customer_parcel_incidents (диалоговая demand-ветка, receipt, carry/modal) | 48/614 | 202317604 |

Статическая сверка 21 dialogue diff: меняются только объявленные NPC speaker headers;
cues, response tags/условия/тексты и окончания веток идентичны. Две sign resources не изменены.
Native Import обновил compiled headers, но общий gate FAIL из-за shutdown ObjectDB/resources,
PagedAllocator и dummy RID diagnostics (`import-20261016-202114387.*.log`); это не PASS.
MCP reimport вызывает update_file и оставил stale compiled headers; native Import выполнен
после штатного закрытия clean editor, затем guarded launcher восстановил редактор.
Красные pre-import/fixture/cache-precondition прогоны сохранены, не засчитаны как приёмка.
D1 review REVIEW_PENDING; D2 runtime/parser/review NOT_RUN.
Границы: отсутствие ключа против явного null,
int/float/bool/составные значения, нечисловой add без мутации, запрещённые persistent Objects,
смена street/service/дня/тела, закрытый ctx и технический повтор callback.
Изменение схемы покрывать в D2 целиком, со строгим отказом до записи неподдерживаемого save.

## Owner QA / blockers

Не требуются новые имена/сюжеты для проверки API. Авторские примеры не становятся каноном.
Rendered QA отдельно; нет разрешения менять addon или заменять панель демонстрационным balloon.
