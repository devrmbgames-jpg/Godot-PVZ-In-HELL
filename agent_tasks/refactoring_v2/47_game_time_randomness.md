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

World/game timestamp — monotonic integer elapsed simulation ticks с explicit quantum/remainder в time owner; `C_DayCycle` остаётся authority player-driven day/phase transitions. Daily schedules/deadlines use calendar labels/events, local durations use elapsed ticks. Pause freezes elapsed gameplay; sleep/skip changes calendar without inventing elapsed night duration/automatic day length. Physics callback delta and real/UI clock separate. Save includes clock/remainder/calendar state; repeated reload/phase event cannot duplicate daily outcome.

Random decision key = world seed + stable actor ID + game day + decision/action kind + persisted decision sequence при repeated decisions. Canonical byte encoding/hash algorithm явно fixed; не использовать engine/Python process hash или unordered Dictionary traversal как reproducibility contract. При same state/order output одинаков; Jolt deterministic lockstep не обещается.
Use existing pinned Godot RNG with golden seed/output fixtures, not a new random framework. Seed mixing declares field framing/encoding/hash, signed range and algorithm/version; RNG/dependency upgrades update this explicit contract. Decision sequence increments only on committed decision, not rejected query/preview. Save/reload fixtures and stable sorted inputs prove repeatability for the pinned runtime; no lockstep or cross-engine-version guarantee.

Это foundation **до** 41–46. Существующие day/schedule decisions мигрируются здесь; новые AI/LOD consumers сразу используют готовый контракт. Изменение time/seed save shape требует schema version bump и current-format roundtrip из 04 в этом же milestone; старые saves не мигрируются.

## Acceptance

Macro AI и daily decisions воспроизводимы из одинакового seed/state.
Gameplay code не использует wall-clock для domain rules без explicit contract.

## Validation

Time/seed unit tests + save/restore deterministic fixture.
