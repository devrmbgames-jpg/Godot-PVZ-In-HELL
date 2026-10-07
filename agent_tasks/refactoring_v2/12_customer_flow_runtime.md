# Refactoring v2.12 — CustomerFlow: активный lifecycle визита

Status: **PLANNED**

Зависимости: [11_customer_flow_planning.md](11_customer_flow_planning.md).

## Goal

Вынести регулярный lifecycle активного Customer из монолитного `CustomerFlowService` в явное scheduled ECS поведение.

## Scope

Разобрать `_step/step_service` и фазовое состояние Customer:
- queued/approaching/waiting/service/dialogue/inspection/leaving/aggressive;
- timers и timeout progression;
- intent/navigation handoff;
- disappearance/death cleanup;
- связь Customer ↔ visit ↔ package.

Не переносить код механически в один огромный System. Если разные фазы имеют разные scheduling/query contracts — разделить их.

## Service boundary

Оставить в Service только хорошо названные one-shot operations, например lookup/bind/finish/explicit transition, если они действительно переиспользуются из разных владельцев.

## Acceptance

- регулярный Customer lifecycle читается из `S_*` и query/deps;
- Service не владеет generic per-frame `_step`;
- не появляется новый hidden dispatcher под другим именем.

## Validation

Customer flow/service/inspection профильные GUT + parser изменённых файлов.
