# Живые жители / 01 — минимальная основа без второго roster

Status: **PLANNED**
Technical: **NOT_STARTED**
Execution order: **PARENT**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](../references/task-refactor-2026-10-17/npc_living_society/01_foundation_and_contracts.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](../README.md).


Parent: [общая задача](../npc_living_society.md).

## Goal / acceptance

Единые владельцы личности, потребностей, отношений, навыков, целей и ресурсов;
минимальный работающий прототип без будущих пустых API. Все границы/миграции Source обязательны.

## Current

Реализация не начата. Фундамент не означает заново создавать уже реализованные
контракты соседних ТЗ. Общий статус программы остаётся у Parent.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| F1 | Сверить фактические shared contracts и сформировать минимальные прототипные карточки трёх жителей без нового registry. |
| F2 | Добавить только недостающие используемые поля/receipts для 02, со своим codec/preflight и тестовым сценарием. |

R1/R2 жителей остаются у их задачи; F1 принимает их evidence, а не копирует реализацию.
Реальные кошелёк, hunger, inventory, календарь, motion и live Relationships не получают дублей.

## Entry points / dependency gates

[Жители R1/R2](../district_authored_residents_and_resurrection.md), текущий NpcRecord/C_District,
C_Hunger/S_Hunger и C_NpcDecision; [PVZ-NPC01](../npc_perception_relationship_graph_and_social_planning.md)
для общего knowledge/graph, [торговля](../district_resident_barter_and_buyback.md) для ресурсов/операций.
Читать [GDD](../../../docs/game_design/npc_needs_and_intrigue_gdd.md) только по прототипу и актуальной границе.
Если части основы нет, работать в её owning-пакете, не объявлять отсутствие поводом создать параллельный API.

## Next

F1 → F2, затем автоматически [02](02_needs_and_utility.md) через Parent.
Нельзя требовать полного авторского roster/owner QA всех смежных задач для технического пилота.

## Validation / review

Новые runtime/review NOT_RUN. Проверить single ownership, stable IDs, отсутствие
побочных эффектов getters, новый campaign без миграции/перезаписи старого файла,
сохранение минимального прототипа. Существующие доказательства повторять только при изменении контракта.

## Owner QA / blockers

Имена/сюжеты прототипа не канон. Данные явно черновые, окончательное наполнение остаётся
в authoring-пакете жителей. Никаких неиспользуемых framework API «для следующих шести этапов».
