# Refactoring v2.43 — Smart Objects / Affordances / Reservations

Status: **PLANNED**

Зависимости: Templates/Traits и typed contracts.

## Goal

Сделать единый capability-based язык взаимодействия Entity с миром.

## Scope

- authored Smart Object definition;
- affordances;
- slots/markers;
- reservation Relationships;
- eligibility/preconditions;
- execute/cancel lifecycle;
- common contract для player, GOAP, LimboAI, quests и Dialogue.

## Constraints

Smart Object не должен становиться новым gameplay authority. Runtime state хранится в ECS/Relationships; scene markers — authoring/presentation.

## Acceptance

Минимум Chair/Sit, Bed/Sleep или аналогичные representative objects работают через общий contract без проверки concrete scene class.

## Validation

Reservation/content validation + representative interaction tests.
