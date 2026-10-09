# Refactoring v2.00.04 — migration, persistence и validation audit

Status: **DONE**

Зависимости: [00_03_simplification_reference_audit.md](00_03_simplification_reference_audit.md).

Рекомендуемый reasoning: **xhigh**.

## Goal

Проверить, что отшлифованную target architecture реально можно внедрить без опасных half-migrations, потери save identity, сломанных resource paths и необнаруживаемых configuration errors.

## Migration review

Для каждого крупного перехода определить:
- start state;
- target state;
- migration sequence;
- временный adapter, если действительно нужен;
- точку удаления adapter;
- автоматический gate, доказывающий завершение;
- rollback/coherent commit boundary.

Особенно проверить:
- Service → System/Observer ownership;
- horizontal roots → vertical domains;
- direct cross-domain calls → explicit contracts;
- manual composition → Templates/Traits;
- existing interaction → Smart Objects;
- current NPC logic → Schedule/Utility/GOAP/LimboAI;
- physical-only NPC → Simulation LOD.

## Persistence review

Проверить влияние на:
- stable IDs;
- Relationships;
- scene/resource paths;
- Entity Templates;
- Traits;
- SpawnContext;
- schedules;
- GOAP state;
- Smart Object reservations;
- Simulation LOD;
- save schema/version migration.

Отдельно решить для каждого transient слоя:

> Это действительно нужно сохранять, или безопаснее реконструировать после load?

Не сериализовать transient runtime state только потому, что он существует.

## Validation matrix

Убедиться, что дешёвая автоматика покрывает:
- Service/System smells;
- canonical domain layout;
- forbidden domain dependencies;
- broken `res://` paths;
- Template/Trait requires/provides/conflicts;
- placed scene capability requirements;
- Smart Object slots/executors;
- GOAP actions/executors;
- stable ID uniqueness;
- Dialogue references;
- schedule locations;
- animation references;
- content ranges;
- strict "legacy architecture absent" gates.

Migration baseline/allowlist может существовать только временно и должен иметь task, который гарантированно его обнуляет.

## Milestone sizing

Проверить, что каждый implementation milestone:
- можно завершить за один длинный рабочий цикл;
- можно закоммитить coherent state;
- можно узко проверить;
- можно откатить отдельно;
- не требует долго жить в invalid half-state.

Слишком крупные tasks дробить; искусственно мелкие tasks, которые сами по себе оставляют опасный half-state, объединять.

## Acceptance

- у каждого архитектурного перехода есть безопасная migration sequence;
- persistence/save implications учтены до изменения соответствующих contracts;
- каждый temporary compatibility mechanism имеет точку удаления;
- validators/acceptance gates способны доказать отсутствие legacy state;
- размеры milestones реалистичны.

## Validation

Planning + validator tests only. Gameplay/runtime refactor запрещён.

## Current — повторный migration/persistence audit 2026-10-07

Audit выполнен после отдельного commit 00_03. Владелец явно исключил old-save migration/backward compatibility: project ранний; save skill теперь следует этому решению. Existing schema 2 и Night prepared-Morning/reset/retry/preflight semantics проверены по actual WorldSnapshotService, DistrictSnapshotRules, AutosaveStore/NightSaveService. Новый target сохраняет physical roots и ECS aggregate; прежняя forced actor-shell migration исключена. Таблицы ниже — исправленный план, не результаты будущего runtime implementation.

### Migration / rollback matrix

| Переход / start | Target / sequence | Temporary mechanism и removal | Completion gate | Coherent commit / rollback |
| --- | --- | --- | --- | --- |
| Service→System/Observer: shell ticks/time/query | 04 baseline → 10 inventory → 40 typed foundation → 11–25 migrate responsibility/all callers → 26 cleanup → 27 acceptance | Только внутри unfinished owned slice; engine-bound exception не generic tick. Execution baseline removal 26 | Layout-independent smells empty baseline + order/flush/idempotency/query regression + relevant GUT, parser, one smoke 27 | Один responsibility/all callers; whole commit rollback |
| Horizontal→vertical: scripts/scenes/resources/tools paths | 40 public contracts → 28 full map/scan updates → 33 transition → 29–31 whole-owner moves → 32 strict | Legacy **unmigrated other owners** могут оставаться до своего move; migrated owner целиком в target. No forwarding script wrappers | Domain strict + dependency strict no exemptions; current-format resource/snapshot whitelist + parser | Owner scripts + `.uid` + incoming ext_resources/tests/codec in one commit; rollback restores map/paths/version вместе |
| Direct cross-domain orchestration | 40 payload/handler ownership/target/result → 28 public manifest → 33 enforce before moves | Synchronous internal operations/stable domain API законны; не wrapper новой bus вокруг old flow | Damage/Commerce/Interaction/Customer/Quest contract fixtures: rejection, commit-before-fact, correlation, no cycles | Один cross-domain flow + handlers/callers/outcomes; old execution path удалён |
| Procedural capability setup→Templates | 41 closed installer manifest + flat recipes + native declarative providers + ready/fixup → 42 Inspector | Optional Template; native intrinsic recipes target providers, no empty assets. Old procedural installer for migrated capability removed within family, no fallback | Isolation/parity/conflicts, duplicate provider notification, failed-build no effects, load without reset, all manifest rows closed | Compiler + first family coherent; every remaining family all scene/factory callers; no representative-only partial DONE |
| Existing interaction→affordance/reservation | 43 existing counter/point + tokenized slot R, player/NPC callers; common execute/cancel | Old class-based branch удаляется для migrated affordance до DONE. Shared executor — один owner, no slot Entity wrapper | Exclusivity, stale token, cancellation/target loss/death, eligibility rejection, content provider negative fixtures | Один existing affordance + оба caller types + scene markers/data; optional new Sit/Sleep отдельно |
| Current NPC decisions→goal/action contract | 44 current schedules/jobs → priority/interrupt selection → native BT execution → owner result | Existing branches используют one action contract; no second BT/FSM leaf dispatcher; GOAP deferred | Goal priority, interruption/resume, timeout/target loss, no action restart, deterministic time/seed fixture | Selection + representative existing obligation + all affected tasks/resources; no mixed authority |
| Scattered participation→ACTIVE/DORMANT | 45A sole participation owner/per-field authority → 45B safe activation/pins → 45C Night save/update-cost acceptance | Retained physical-root and aggregate records are target, not adapters; old participation dispatchers removed within A/B. Body shell/detach deferred | Dormant ID resolution/cleanup, no nav/BT/physics work, HP/inventory/link/metadata continuity, bounded placement failure and no repeated outcomes | A all participation callers, B atomic transitions, C both-mode prepared-Morning fixtures/performance; rollback whole slice |

Обычный Resource UID сохраняется при moves. Stable gameplay ID не вычисляется из нового path и не становится `ecs_id`/instance ID. Open editor scenes меняются через MCP либо закрываются пользователем перед raw edit; Ignore External Changes не используется. Phase 0 сцены не меняла.

### Persistence / reconstruct policy

| State | Сохранять / восстановить | Gate / owner |
| --- | --- | --- |
| Stable NPC/package/order/history/operation IDs | Domain IDs/monotonic sequences; authored world/level ID + local ID; content vs actor vs operation namespaces separate. Metadata mirror refers same actor | 04/28/41/45; duplicate actors/unresolved endpoints reject before mutation; derived resolver not a second ID owner |
| Relationships | Durable inventory/storage/cargo/home/job links: stable endpoints + typed payload; restore после all endpoints | Two-pass restore, missing/dead endpoint policy, reverse caches rebuild; 25/45 |
| Scene/Definition/record script paths | Target authored references/UIDs + explicit safe asset/script whitelist; update loader prefix guards | 28–32; no old-path aliases. Changed serialized shape/path bumps schema; old format rejects |
| Templates/Traits/Profile | Immutable content identity/reference; runtime values отдельны, defaults применяются once before saved state | 41 composition version/current-format fixtures, no shared mutable containers |
| SpawnContext | Durable initial identity/bindings; transient World/Node/Entity handles not serialized; scene selected outside Template | 41 fixup/recipe isolation/no cyclic Scene→Template→Scene |
| Schedule/obligations | Calendar obligations/completed facts/decision sequence; schedule reference. Current local action reset/reselected by Night contract | 47/44/45; no new macro-travel snapshot fields without a feature |
| Utility scores/GOAP/BT | Scores, future plan, BTPlayer/Blackboard/navigation/perception не сохраняются; reconstruct/reselect | 44; GOAP absent. Running session cancel/reset соответствует current Night contract |
| Smart reservations | Night transient reservation not saved; in-session dormancy pins ACTIVE or cancels through owner before transition; durable home/work bindings retained | 43/45 stale token cannot cancel newer reservation, no replay of execution |
| Simulation participation | Existing aggregate placement/history + actor Components/links; enabled/frozen/presentation derived consistently, no second mode store | 45 current-format prepared-Morning snapshots with active/dormant actors; no arbitrary mid-action checkpoint |
| Time/randomness | World seed, elapsed ticks/quantum/remainder, explicit calendar state and committed decision sequence | 47 canonical encoding/seed/output golden fixture, pause/skip/reload; no physics lockstep |
| Physical/UI/transient state | Pose только по domain contract; velocities/hands/dialogue/modal/attacks/projectiles сохраняют current Night-reset semantics; UI не authority | 04/25/45; no serialization of live Object/RID/instance ID |
| Schema/version | Version bump при несовместимом persisted change; validate before live mutation; old/newer versions reject with reason | Нет converter/previous-version roundtrip requirement. User autosave не используется tests и не удаляется tooling |

Snapshot quiescence: finish evening/reset/prepare Morning once, drain pending owning structural/outcome work, freeze/copy snapshot then I/O. Save retries cannot repeat preparation/payment or read live state on worker thread. Restore prevalidates every scene/recipe/resource/ID/link, defaults→saved overlay→links→caches/participation→ready. Required missing endpoint rejects; optional endpoint may drop only under explicit owner policy. Rejected preflight leaves current world intact; unexpected startup failure discards incomplete World. No generic undo framework. Scoped version bump/current-format fixtures belong to the same milestone as persisted contract changes.

### Validation coverage matrix

«План» означает required future acceptance, а не выполненный сейчас runtime check.

| Ошибка | Самый дешёвый доказательный gate | Owner / removal deadline |
| --- | --- | --- |
| Hidden Service tick / System wrapper | 03 layout-independent static smells + good/bad fixtures, broad-query/manual role review | 10 inventory; zero baseline 26/27 |
| Wrong canonical roles / legacy roots | Existing `validate_domain_structure.py` transition/strict + fixture tests | 28/32; strict не ожидается на current horizontal tree |
| Forbidden imports / class_name / cycles | 33 directed edge + public symbol index; public cycle/forbidden edge, comments/strings false-positive fixtures; dynamic adapters review | Before moves; exemption exact edge/symbol removed by owner's DONE, zero after 32 |
| Broken res paths / prefix guards / UIDs | Project structure scan + ResourceLoader/parser + new-format codec/snapshot fixture | 28–32, not only repository text replacement |
| Trait requires/provides/conflicts | Same 41 compiler used by Inspector/factory/Doctor; positive/negative fixtures | 41 before DONE, no second validator rules |
| Placed scene capabilities | Capability/node/export/animation/binding provider | 41/42, Smart Object fields 43 |
| Smart slots/executor | Missing slot/marker/token/executor negatives + reservation lifecycle | 43 before DONE |
| GOAP actions | Not in baseline; future evidence/task must add its provider/tests | DEFER, no empty mandatory gate |
| Stable ID uniqueness/endpoints | Content + save validation before registry/restore; duplicate spawn blocked before GECS ID-replacement behavior | 04/41/45, full scan 46 |
| Dialogue references/actions | Imported cue/resource/declared ctx/tag validation, no mutation execution; repeated-entry/late-await/session result fixtures | 40 provider; quest/trader authoring providers 19/24, aggregate 46 |
| Schedule location/action | Resolve authored location + allowed action/time bounds, failure fixture | 44 provider, 46 aggregate |
| Animation/resource ranges | Scene capability names and Definition ranges, readable resource/field diagnostics | 41–44 providers, 46 full scan |
| Absent legacy architecture | Strict layout/dependency, closed inventory, no wrapper/duplicate authority review | 27 execution; 32 paths; 49 composition/AI/LOD |
| Why/rejection unobservable | Read-only reason/provenance snapshot fixture; bounded trace | 40–45 providers, 48 UI/owner QA |
| Broken roadmap/order/readiness/scope | `validate_refactoring_preflight.py`: graph/links/encoding, unique verdict/status, proposal/README/next action, six scores/blockers; commit/index footprint | Phase 0 with 20 good/bad fixtures; scope checks committed/staged changes, not unrelated user dirt or runtime correctness |

Existing regressions usable at implementation: `test_customer_flow.gd`, `test_customer_timing.gd`, `test_district_population.gd`, `test_district_bt_lifecycle.gd`, `test_npc_attacks.gd`, `test_s_grab.gd`, `test_physical_slots.gd`, `test_wallet.gd`, `test_hunger.gd`, `test_refusal_quest.gd`, `test_save_data.gd`, `test_persistent_runtime.gd`, `test_district_snapshot.gd`. Actual new fixtures/CLI options are recorded by owning implementation task before it is DONE; nonexistent future commands are not reported as PASS.

### Milestone sizing

- 11–13: each scheduled responsibility coherent; no new compatibility bridge between tasks. Unmigrated outcome operation is a separate owner, not a duplicate runtime path.
- 21: slice held/push/slots/cargo by authority + all direct callers and physics tests; each temporary adapter removed within its slice.
- 29–31: whole owner per commit; NPC/Customer dependency hierarchy decomposed before moves, population merged into npc; incoming callers/references/codec move together; parent DONE after all named owners.
- 41: compiler core + first working family, then complete each remaining representative family/all callers; 42 only Inspector ergonomics.
- 43/44: existing executor/obligation before variants; no new mechanic/GOAP demo requirement.
- 45: A sole participation writer, B safe transition, C Night save/performance; speculative actor-shell/body-cast migration removed. Dormant body memory retained explicitly.
- 40: foundation before 11, bounded boundary/caller slices; owner scheduler migration stays 11–25, final cross-flow gate 27. No duplicate handler while old scheduled responsibility awaits its own task.
- 24: existing Trader catalog/profile dual path removed; 19 authored quest Definition variants; 41 closed installer manifest, native declarative recipes accepted without duplicate setup.
- 10/28 prepare concrete slice manifests using actual inventory; tasks can split locally when measured scope requires, preserving parents' full acceptance. No deferred wrapper survives declared DONE.

Each slice commits a runnable contract; no requirement to leave an invalid branch between files. Revert uses complete commit boundaries including paths/schema/tests, never force reset unrelated user edits.

### Existing project validation failures

`python utils/validate_project_structure.py` currently FAIL: 31 pre-existing diagnostics. One missing `truck_shift_gate_smoke.gd` reference and 30 missing Task state headings across six top-level R26 files. `git ls-files` and unchanged-file diff confirm these inputs were already tracked/unchanged. They are assigned to **03 infrastructure repair before runtime migration**, not silently allowlisted. Phase 0 does not restore a gameplay smoke script or edit unrelated R26 tasks. These failures do not invalidate the planning graph, but full project-structure PASS is mandatory before 10 and at subsequent acceptance.

## Validation result

- `python utils/validate_refactoring_preflight.py`: PASS (50 tasks, explicit dependencies/order/cycles/local links/encoding).
- `python -m unittest discover -s tests/tools -p test_validate_refactoring_preflight.py`: PASS, 20 tests.
- Commit footprint 0485062e/56482e6c/f2c81333: PASS via `--phase0-commit`; index scope checked before this task's commit. Runtime/config/addon changes are rejected by fixtures; unrelated unstaged user edits excluded.
- `python utils/validate_domain_structure.py`: PASS (transition).
- `python -m unittest discover -s tests/tools -p test_validate_domain_structure.py`: PASS, 4 tests.
- `python utils/validate_project_structure.py`: FAIL, known 31 pre-existing diagnostics assigned above.
- `git diff --check`: PASS.

Runtime/GUT/Godot parser/editor/rendered checks не запускались; project-owned `.gd` не изменялись. Validator fixtures — Python tooling tests, не gameplay implementation.

## Next

[00_05_preflight_readiness_gate.md](00_05_preflight_readiness_gate.md): второй полный review исправленного 50-task roadmap, scorecard и final verdict.
