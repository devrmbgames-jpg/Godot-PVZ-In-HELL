# Refactoring v2.48 — Gameplay Debugger

Status: **PLANNED**

Зависимости: AI/Traits/LOD contracts готовы.

## Goal

Сделать архитектуру наблюдаемой без логирования всего мира.

## Selected Entity view

Показывать как минимум:
- Components;
- Relationships;
- current Goal;
- GOAP plan/action;
- LimboAI status/reference;
- Intent;
- reservations;
- perception summary;
- Simulation LOD;
- recent gameplay events.

## Constraints

Debugger read-only по умолчанию.
Не создавать debug gameplay authority.
Использовать существующий LimboAI debugger, а не дублировать его tree inspector.

## Acceptance

По выбранному NPC можно понять "почему он сейчас делает это" без поиска по нескольким Services и постоянного stdout.

## Validation

Debug data provider tests + owner editor QA.
