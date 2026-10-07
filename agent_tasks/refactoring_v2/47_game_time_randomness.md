# Refactoring v2.47 — unified Game Time и deterministic randomness

Status: **PLANNED**

Зависимости: [32_domain_shared_core.md](32_domain_shared_core.md), strict dependency rerun задачи 33 PASS.

## Goal

Убрать смешение simulation delta, physics frame, game clock, day time и real/UI time; сделать важные random decisions воспроизводимыми.

## Work

- определить typed/explicit time contracts;
- перевести schedules, macro AI, offscreen simulation и persistence на единый world/game timestamp;
- real/UI time оставить вне gameplay authority;
- определить deterministic seed derivation из world seed + stable entity ID + game day + decision/action ID;
- не требовать deterministic lockstep всей физики.

World/game timestamp — monotonic integer simulation ticks в time owner; `C_DayCycle` остаётся authority explicit day/phase transitions, calendar labels не второй накопитель delta. Pause/skip/Night→Morning mapping документируется и сохраняет текущую семантику. Physics callback delta и real/UI clock отдельны и не сохраняются как gameplay timestamp.

Random decision key = world seed + stable actor ID + game day + decision/action kind + persisted decision sequence при repeated decisions. Canonical byte encoding/hash algorithm явно fixed; не использовать engine/Python process hash или unordered Dictionary traversal как reproducibility contract. При same state/order output одинаков; Jolt deterministic lockstep не обещается.

Это foundation **до** 41–46. Существующие day/schedule decisions мигрируются здесь; новые AI/LOD consumers сразу используют готовый контракт. Изменение time/seed save shape требует schema version bump и current-format roundtrip из 04 в этом же milestone; старые saves не мигрируются.

## Acceptance

Macro AI и daily decisions воспроизводимы из одинакового seed/state.
Gameplay code не использует wall-clock для domain rules без explicit contract.

## Validation

Time/seed unit tests + save/restore deterministic fixture.
