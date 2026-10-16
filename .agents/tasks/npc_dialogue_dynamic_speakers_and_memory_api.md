# Диалоги — динамический говорящий и пять операций памяти

Status: **PLANNED**
Technical: **NOT_STARTED**
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

Реализация этой задачи не начата. Подстановки speaker уже частично существуют;
переиспользовать их, не заменять UI/adдон. Историческая запись о чужом dirty street ctx
требует сверки actual worktree, а не предположения, что изменение всё ещё незакоммичено.

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

Начать с D1 на двух участниках одного архетипа с разными именами; затем продолжить D2/D3
без отдельного разрешения на каждый пакет в рамках команды выполнить backlog.

## Validation / review

Новые runtime/parser/review NOT_RUN. Границы: отсутствие ключа против явного null,
int/float/bool/составные значения, нечисловой add без мутации, запрещённые persistent Objects,
смена street/service/дня/тела, закрытый ctx и технический повтор callback.
Изменение схемы покрывать в D2 целиком, со строгим отказом до записи неподдерживаемого save.

## Owner QA / blockers

Не требуются новые имена/сюжеты для проверки API. Авторские примеры не становятся каноном.
Rendered QA отдельно; нет разрешения менять addon или заменять панель демонстрационным balloon.
