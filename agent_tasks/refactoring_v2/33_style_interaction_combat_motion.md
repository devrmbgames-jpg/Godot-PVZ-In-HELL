# Refactoring v2.33 — Code Style: Interaction, Combat и Motion

Status: **PLANNED**

Зависимости: 32_style_npc_customers.md.

## Goal

Сделать physics-heavy код читаемым человеку без изменения его физической семантики.

## Scope

- interaction/grab/push/slot/cart;
- combat/damage;
- motion/navigation/physics solvers;
- связанные entities/glue.

## Extra focus

- ray/shape queries получают intent comments, когда используются цепочкой;
- coordinate-space и transform conversions явно разделяются;
- intermediate vectors/results типизированы и названы по роли;
- physics callback constraints документированы там, где они неочевидны;
- long expressions разбиты без изменения порядка вычисления;
- performance-sensitive hot paths не усложнять аллокациями только ради красоты.

## Acceptance

Style gate + parser PASS.
Physics ownership и ordering не изменены.

## Validation

Профильный grab/combat/physics regression только для файлов, где style cleanup потребовал не-механической перестройки.
