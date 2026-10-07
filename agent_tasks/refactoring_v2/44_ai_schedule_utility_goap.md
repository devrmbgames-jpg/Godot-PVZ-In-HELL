# Refactoring v2.44 — AI stack: Schedule → Utility → GOAP → LimboAI

Status: **PLANNED**

Зависимости: Smart Objects, unified time foundation, stable NPC domain.

## Goal

Разделить macro planning и realtime execution.

## Ownership

- authored schedule — deterministic obligations;
- Utility/Goal selection — текущий приоритет;
- GOAP — редкие multi-step macro plans с альтернативами;
- LimboAI — local execution, combat, interrupts и realtime reactions;
- ECS — authoritative state.

## Constraints

- GOAP world state derived from ECS, не второй authority;
- planner не управляет physics;
- combat остаётся LimboAI/local systems;
- action sets ограничиваются context/buckets;
- planner имеет budget/cadence и просыпается по meaningful events.

## Acceptance

Representative non-combat goal строится GOAP plan и исполняется через LimboAI/action contract.
Простой authored schedule не проходит через planner без причины.

## Validation

Planner unit tests + deterministic fixture + NPC smoke.
