# Refactoring v2.47 — unified Game Time и deterministic randomness

Status: **PLANNED**

Зависимости: domain ownership стабилен.

## Goal

Убрать смешение simulation delta, physics frame, game clock, day time и real/UI time; сделать важные random decisions воспроизводимыми.

## Work

- определить typed/explicit time contracts;
- перевести schedules, macro AI, offscreen simulation и persistence на единый world/game timestamp;
- real/UI time оставить вне gameplay authority;
- определить deterministic seed derivation из world seed + stable entity ID + game day + decision/action ID;
- не требовать deterministic lockstep всей физики.

## Acceptance

Macro AI и daily decisions воспроизводимы из одинакового seed/state.
Gameplay code не использует wall-clock для domain rules без explicit contract.

## Validation

Time/seed unit tests + save/restore deterministic fixture.
