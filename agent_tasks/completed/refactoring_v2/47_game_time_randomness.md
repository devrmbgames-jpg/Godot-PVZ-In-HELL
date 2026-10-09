# Refactoring v2.47 — unified Game Time и deterministic randomness

Status: **DONE — PASS**

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

## Result

`C_DayCycle` retains player-driven calendar authority and owns an isolated typed `GameClock`.
`S_GameTime` alone advances monotonic integer microsecond ticks and fractional remainder; prefab
copies cannot share their clock Resource. Clock runs before the quantized Input/Interaction/GamePlay
groups; native Physics callbacks keep their explicit frame/delta contracts. Pause/Night freeze elapsed
time, and sleep advances calendar without synthesizing night duration. Shift duration reads start/end
ticks; NPC cadence persists sampled/retained ticks in its existing ECS-owned person record.

`DecisionRandomRules` fixes versioned UTF-8 length framing, SHA-256 and the nonnegative signed-64-bit
seed range for the pinned Godot 4.7.1 RNG. Existing customer initial/inspection/followup/clue decisions,
package variants, macro schedules/activity/cadence, replacement profiles, remains, social incidents and
delivery offers now use saved world seed + stable actor/action ID + day + kind + committed sequence.
Random candidate IDs/paths are sorted; authored schedules and the durable visit queue retain their
explicit ordering. Rejected activity previews do not increment the persisted sequence. No process
hash, global pick_random or wall-clock rule remains in gameplay domains/shared/debug. Cryptographic
package identity generation and derived terminal display fingerprints remain outside decision seeds.

Schema 9 stores clock/remainder/seed/calendar and NPC cadence/sequence. The closed codec rejects
missing/invalid clock fields and future cadence timestamps before changing live state. The native
Variant golden contains nondefault values and proves restored next-decision output. Older formats
are rejected/protected without migration or automatic overwrite.

Night I/O retries use the explicit Storage group and transient operational seconds after GamePlay,
so a frozen gameplay clock cannot starve atomic write retries. Headless fixtures now drive Clock
and Storage consistently; the full frame fixture preserves actual main-level group order. Inspection
smoke owns its main PackedScene and host teardown, and its delivery operation executes outside assert.
Population/light/route query caches and their callbacks end at World handoff/exit, releasing retained
Component scripts without adding a scheduler or changing gameplay authority.

Canonical contracts and access/migration manifests are updated; `docs/game_time.md` documents units,
ownership, seed framing/range/version, exact native RNG fraction bits and persistence behavior.
No addons changed, rendered gameplay or subjective visual QA performed.

## Validation results

Executed 2026-10-09:

- Final changed-file native parser: **72 files PASS**, zero errors/warnings
  (`tests/artifacts/refactoring_v2_47_final_parser.log`).
- Final 43-script GUT after all implementation/tooling edits: **731/731 PASS**, **6549 assertions**,
  zero runtime diagnostics (`tests/artifacts/refactoring_v2_47_closed_gut.log`), including 11 time/RNG
  tests, the native current-format persistence baseline **4/4**, NPC/customer/delivery/remains,
  shift completion and actual main/primitive World startup/teardown.
- Explicit pause/due-step regression with inherited NPC surface: **49/49 PASS**, 285 assertions.
  The complete native graph already clears consumed due intervals through S_NpcRoute; no extra
  competing cleanup owner was added.
- Actual main-level vertical slice: **PASS**, including committed ledger/outcome/ownership/damage,
  scheduled Night and passive fresh startup (`vertical_slice-20261009-082918983.log`).
- Night **write + separate-process restore PASS**, retaining nondefault elapsed ticks/remainder/seed,
  calendar, debt, inventory, stable physical links and prepared population
  (`night_persistence-write-20261009-082928100.log`, `night_persistence-restore-20261009-082937241.log`).
- Actual native customer booth/parcel return/refusal smoke: **PASS without shutdown diagnostics**
  (`customer_inspection-20261009-082538613.log`). The initial run's resource leakage was investigated
  and resolved through explicit scene ownership and query-cache lifetime; no errors were ignored.
- Strict architecture, project structure/dependency and native persistence manifest checks: **PASS**.
- Domain-validator fixtures **33/33 PASS**; persistence-baseline validator fixtures **5/5 PASS**.

## Current / Next
**DONE — PASS**. Canonical elapsed clock/calendar/randomness and current-format persistence gates
complete, with no legacy scheduler/random path or ignored native diagnostics in this scope.
Continue [41 — Entity Templates / Traits](../../refactoring_v2/41_entity_templates_traits.md) immediately, then dependency
order through 49. No old-save migration; no rendered/subjective QA; do not start Phase 3.
