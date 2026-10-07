# Refactoring v2.15 — NPC brain, perception и traits

Status: **PLANNED**

Зависимости: [14_district_lifecycle.md](14_district_lifecycle.md).

## Goal

Убрать `S_NpcDecision -> NpcBrainService.tick` как скрытый AI scheduler, сохранив LimboAI как decision runtime.

## Keep as runtime adapter

`NpcBrainService.install/update_tree/abort` могут оставаться adapter API, потому что они управляют LimboAI runtime.

## Move scheduled ownership

Явно распределить:
- decision interval/budget;
- perception cadence;
- footsteps/noise ageing;
- trait progression;
- service-role advancement;
- BT update scheduling;
- post-decision cleanup.

Не создавать новый Mega-System. Если perception/traits/noise имеют самостоятельную cadence/query — выделить Systems.

## Acceptance

- `NpcBrainService.tick()` удалён или перестал быть scheduler;
- LimboAI tree update остаётся явным узким adapter call;
- AI execution order виден из Systems/deps;
- BT/Blackboard не становится второй authority базой.

## Validation

NPC behavior/performance contracts, BT validator, parser.
