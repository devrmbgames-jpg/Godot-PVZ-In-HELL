# Refactoring v2.16 — NPC route, service role и district behavior

Status: **PLANNED**

Зависимости: [15_npc_brain.md](15_npc_brain.md).

## Goal

Перенести time-based route/service-role progression в явные Systems, оставив сервисам расчёт маршрута и explicit commands.

## Scope

- `NpcRouteService.tick/process_pending`;
- route interval, stall/blocked timers, per-frame planning budget;
- `C_NpcRoute`;
- scheduled части `NpcServiceRole`;
- social/activity/home-delivery lifecycle, если inventory классифицировал их как scheduled;
- взаимодействие с `S_NpcIntent`.

## Direction

Вероятный целевой дизайн:
- `S_NpcRoute` владеет route state progression/budget;
- route calculation helper остаётся `NpcRouteSolver/Rules` или узким Service;
- explicit enqueue/defer/finish commands могут оставаться service API.

## Acceptance

- route lifecycle и budget видны в ECS graph;
- `NpcRouteService.tick()` отсутствует;
- нет service chain, которая после BT скрытно запускает route scheduler.

## Validation

NPC route/performance/district tests + parser.
