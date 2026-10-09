# Refactoring v2.48 — Gameplay Debugger

Status: **PLANNED**

Зависимости: [46_content_doctor.md](46_content_doctor.md), AI/Traits/LOD contracts готовы.

## Goal

Сделать архитектуру наблюдаемой без логирования всего мира.

## Selected Entity view

Показывать как минимум:
- Components;
- Relationships;
- current Goal;
- active obligation/action и selection/cancel reason; GOAP plan только при введённом optional planner;
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

Read-only diagnostic snapshots/reason codes создаются в 40–45 вместе с владельцами состояния. Задача 48 добавляет selected-Entity view, а не впервые изобретает observability после AI/LOD migration.

## Acceptance

По выбранному NPC можно понять "почему он сейчас делает это" без поиска по нескольким Services и постоянного stdout.

## Validation

Debug data provider tests + owner editor QA.
