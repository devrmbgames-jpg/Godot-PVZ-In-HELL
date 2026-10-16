# PVZ-B01 — ConfigFile storage, отложенный scope

Status: **DEFERRED**
Technical: **DEFERRED**
Execution order: **990**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/pvz_b01_configfile_save_storage.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Сохранить полный отложенный запрос нативного ConfigFile storage, согласованного размера,
checksum/атомарной записи/retry и защиты старого слота. Ничего из исходного ТЗ не
вычёркнуто, но оно не является разрешением возобновить неудавшуюся миграцию.

## Current

Последнее решение владельца от 2026-10-16: простой storage финального Dictionary через
ConfigFile либо возврат прежнего формата. Выполнен fallback; production поддерживает binary PVZH1.
ConfigFile потерял exact Float64 freshly captured variation; дополнительный serializer
и предложенный cleanup Nodes не одобрены. Требуемый размерный fix также не объявлен выполненным.
Историческая schema 19 не фиксирует нынешнюю версию; читать actual AutosaveStore.SCHEMA_VERSION.

## Work packages

Все исходные пакеты ConfigFile/size/integrity/restore остаются DEFERRED.
Новые независимые gameplay-поля повышают свою schema по текущему контракту,
но не возобновляют эту задачу. Не запускать прежние эксперименты при обходе backlog.

## Entry points / dependency gates

AutosaveStore, S_NightSave/NightSaveService, текущий codec и prepared_snapshot.
[Восприятие](npc_perception_relationship_graph_and_social_planning.md), жители, диалоги
и общество используют поддерживаемый storage, а не ждут полного DONE B01.
Постоянное социальное состояние не уносится в отдельный файл ради обхода этого решения.

## Next

Пропустить при автономном исполнении и продолжить независимые задачи.
Возвращаться только после нового явного решения владельца именно о B01;
общая команда «все задачи» не отменяет зафиксированный технический fallback.

## Validation / review

Исторические probes/rollback evidence сохранены в Source и .artifacts/configfile_attempt/.
Миграция не принята; новые проверки и исправление размерного несоответствия: NOT_RUN.
Нельзя объявить binary fallback доказательством выполненной ConfigFile-приёмки.

## Owner QA / blockers

OWNER_FALLBACK / DEFERRED. Не улучшать точность самописным Float64-форматом,
не выполнять Nodes cleanup или upgrade движка без нового scope.
