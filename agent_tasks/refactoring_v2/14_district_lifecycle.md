# Refactoring v2.14 — District lifecycle, population и schedule

Status: **PLANNED**

Зависимости: [13_customer_outcomes.md](13_customer_outcomes.md); customer planning/runtime завершены через 11–13.

## Goal

Сделать районный scheduled lifecycle явным и убрать `S_District -> DistrictScheduleService.tick` shell pattern.

## Scope

- `S_District`;
- `DistrictScheduleService`;
- scheduled части `DistrictPopulationService`;
- day/phase placement transitions;
- death/placement reconciliation;
- spawn/despawn/participation one-shot operations.

`DistrictPopulationService` не нужно уничтожать: lookup, spawn commands и registry operations могут оставаться сервисом.

## Acceptance

- phase/schedule progression принадлежит System/Observer;
- population Service не становится scheduler;
- district ordering относительно Customer/Day/NPC Intent остаётся явно заданным через deps/events.

## Validation

District population/schedule tests + parser.
