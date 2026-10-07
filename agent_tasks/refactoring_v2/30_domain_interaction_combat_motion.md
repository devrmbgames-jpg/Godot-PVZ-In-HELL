# Refactoring v2.30 — vertical domains: Interaction, Combat и Motion

Status: **PLANNED**

Зависимости: [28_domain_layout_contract.md](28_domain_layout_contract.md), соответствующие execution-refactor задачи завершены.

## Goal

Собрать interaction/combat/motion ownership вертикально после исправления scheduling boundaries.

## Scope

```text
content/domains/interaction/
content/domains/combat/
content/domains/motion/
```

Physics engine-bound solvers остаются solver/glue, но получают понятного domain owner либо shared owner.

## Acceptance

- interaction/combat/motion не зависят от старых horizontal paths;
- Systems/Observers/Services находятся рядом со своими domain contracts;
- cross-domain взаимодействие идёт через typed contract/API, а не file-location coupling;
- no compatibility wrappers после завершения.

## Validation

Grab/input/combat/motion parser + профильные GUT + structure validator.
