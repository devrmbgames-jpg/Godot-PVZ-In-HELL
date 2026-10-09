# Refactoring v2.18 — Challenge lifecycle

Status: **DONE**

Зависимости: [17_combat.md](17_combat.md), [13_customer_outcomes.md](13_customer_outcomes.md).

## Goal

Перенести общий time-based Challenge lifecycle из `ChallengeService.tick` в `S_ChallengeRuntime` либо несколько явных Systems/Observers.

## Preserve

- arm/activate/cancel explicit API;
- condition Systems;
- Challenge actor/effect Relationships;
- result publication и presentation separation.

## Direction

`ChallengeService` может сохранить one-shot session commands и lookup.
Elapsed/timeout/result display/cleanup progression принадлежит System.
Discrete resolution/cleanup может перейти в Observer, если это упрощает ownership.

## Acceptance

`S_ChallengeRuntime` больше не является wrapper вокруг service tick.
Condition computation, lifecycle и outcome consequences имеют отдельные понятные владельцы.

## Validation

Challenge light/gaze/floor/runtime tests + parser.

## Result / Current

18.A–18.C завершены по полной inventory: S_ChallengeRuntime владеет elapsed/timeout/violation/result-display progression; ChallengeService.tick удалён со всеми callers. Arm/activate/cancel, one-shot resolve/close и Relationships сохраняют явный synchronous contract. Condition Systems вычисляют измерение, lifecycle выбирает результат, O_CustomerChallengeOutcome применяет discrete consequences после committed fact.

ChallengeActivated публикуется после фактического ACTIVE/elapsed commit. O_ChallengeFloorActivation заменяет setup polling и запрашивает одну автономную плоскость; S_ChallengeFloorSetup и смешанный FloorChallengeService удалены. S_FloorHazard владеет support measurement и damage clock с прежним preparation/grace/timeout clipping. FloorContactGeometry и GazeTrackingGeometry содержат только explicit measurements. Все UID сохранены при переносах, scene/test wiring мигрирован; old-name aliases отсутствуют.

Queued lifecycle/setup/flight checks revalidate Component/session identity. Floor activation replay не создаёт второй эффект; transient session request ID позволяет фабрике отвергнуть поздний результат заменённого same-key сеанса. Reentrant terminal consumers могут cancel/remove носителя без stale signal/state writes. Floor request IDs не являются persistent save identity; authored floor effects/session clocks transient. Миграция старых save не добавляется.

## Acceptance / Validation result

- PASS: initial GUT 64/64 tests, 466 assertions; final 72/72 tests, 532 assertions across light/gaze/floor/outcomes/customer timing.
- Восемь новых regressions: MANUAL activation/component/calendar replacement, invalid deltas/separate display step, reentrant terminal retirement, activation replay, cancelled pending setup и replaced pending factory receipt.
- PASS: final Godot parser, 17 changed project-owned files, 0 failures.
- PASS: actual headless combat smoke after common lifecycle migration; actual floor smoke after full 18.B/18.C, including Jolt floor/box/airborne contact, shared damage, current main World, dialogue activation, authored safe boxes, debug text, success and cleanup.
- Smoke fixture обновлён под текущий CharacterBody Player/legacy visit и authored damage interval; assertions не ослаблены.
- PASS: architecture (10 remaining lexical findings), project structure, persistence baseline, preflight and git diff --check. Two challenge clock allowances removed.
- Headless editor import зарегистрировал новые classes/UID; его known third-party shutdown diagnostics не используются как чистый parser gate. Standalone parser/GUT/smoke clean.
- Rendered gameplay / subjective visual QA не запускались; product/баланс/клипы не менялись.

Next: 19_hunger_quests.md. Phase 3 не начинать.
