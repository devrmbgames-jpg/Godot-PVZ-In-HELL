# Живые жители Ада — общий владелец программы

Status: **PLANNED**
Technical: **NOT_STARTED**
Execution order: **130**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/npc_living_society.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Девять постоянных жителей и Потерянный, реальные потребности/ресурсы/отношения,
Utility AI для целей и существующие LimboAI BT для исполнения. Физические дома,
закупки, интриги, разрешённые вмешательства в квесты и итоговая читаемая обратная связь
обязательны. Новая кампания без миграции; return_day = death_day + 2.
Полный GDD и исходные ограничения/рецепты/ритм/приёмка сохранены, GOAP не добавляется.

## Current

Игровая реализация не начата. Корневая карточка владеет общим статусом и Next;
десять существующих дочерних карточек сохраняют детали и evidence своих этапов.
Они не являются десятью независимыми root-задачами при обходе backlog.
Общие ID/граф/торговлю не создавать заново под именем «foundation».

## Work packages / dependency route

1. [01 foundation](npc_living_society/01_foundation_and_contracts.md) →
   [02 needs/Utility](npc_living_society/02_needs_and_utility.md) →
   [03 relationships/actions](npc_living_society/03_relationships_and_social_actions.md).
2. После 03: [procurement](npc_living_society/procurement_and_intermediaries.md)
   и [physical homes](npc_living_society/physical_homes_and_privacy.md) независимы по порядку,
   но обе нужны для [04 production/supply](npc_living_society/04_hag_production_and_supply.md).
3. Затем [intrigue](npc_living_society/intrigue_and_local_knowledge.md) →
   [authored quests/pacing](npc_living_society/authored_quest_and_pacing.md) →
   [05 roster/feedback](npc_living_society/05_roster_and_behavior_feedback.md) →
   [06 integration/acceptance](npc_living_society/06_integration_and_acceptance.md).

Этапы проходят автономно в этом порядке, main — единственный writer. Внутри карточки
исполнять один законченный сценарий за пакет, не отдельный review на каждое поле.
Прототип Карга–Дьявол–Скромник, затем Бугай/Элементаль, затем полный состав сохраняется.
Уже доказанную общую основу засчитывать по конкретному контракту/SHA, не реализовывать повторно.

## Entry points / dependency gates

[Жители R1/R2](district_authored_residents_and_resurrection.md) владеют roster/identity/return;
[PVZ-NPC01](npc_perception_relationship_graph_and_social_planning.md) — knowledge и единым graph;
[торговля T1–T3](district_resident_barter_and_buyback.md) — публичными транзакциями.
01/03 только интегрируют/расширяют их. Это stage-gates, не ожидание полной owner QA соседей.
Physical homes явно мигрирует HOME/dormant-контракт; не менять его неявно в needs/BT.
GOAP, глобальные фракции, романтика и полная самостоятельная экономика вне текущего этапа.

## Next

Начать 01 с сверки готовых контрактов жителей/графа/торговли и недостающей минимальной
основы прототипа. Затем автоматически 02 и далее. Зависимость, которой ещё нет в коде,
записать по конкретному owner/stage, не дублировать API и не ждать без проверки всех соседей.

## Validation / review

Текущий runtime/parser/GUT/review всей программы: NOT_RUN. Исторический document PASS
не закрывает игровые gates. Дочерние evidence хранятся у своих этапов; корень содержит
только общий результат/открытые gates, не копии десяти тестовых журналов.
Итоговая 06 не отменяет локальные проверки save/idempotency/resource conservation на ранних этапах.

## Owner QA / blockers

Неподтверждённые имена, цены и личные сюжеты остаются явно прототипными до авторского
решения. Обязательный контент не удалять ради DONE. Разрешение rendered QA отдельное;
отсутствие его не останавливает другие технически готовые задачи backlog.
