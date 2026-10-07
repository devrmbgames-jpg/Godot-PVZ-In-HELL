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

## Current — результат 2026-10-07

Audit выполнен после DONE 00_03. Владелец явно исключил old-save migration/backward compatibility: project ранний. Compatibility ниже относится к authored contracts и новому runtime, не конвертации старого autosave. Existing schema 2 содержит scene/resource/script paths и scene-relative identity; это проверено в snapshot/codec/store, а не предположено по roadmap.

### Migration / rollback matrix

| Переход / start | Target / sequence | Temporary mechanism и removal | Completion gate | Coherent commit / rollback |
| --- | --- | --- | --- | --- |
| Service→System/Observer: shell ticks/time/query | 04 baseline → 10 ownership inventory → 11–25 migrate responsibility + all callers → 26 cleanup → 27 acceptance | Только внутри unfinished owned slice; исключения engine-bound не general tick. Execution baseline removal 26 | Layout-independent smells scan empty baseline + order/idempotency/query regression + relevant GUT, parser, one smoke 27 | Один responsibility и все callers; откат целого commit, не только System file |
| Horizontal→vertical: scripts/scenes/resources/tools paths | 40 public contracts → 28 full map/scan updates → 33 transition → 29–31 whole-owner moves → 32 strict | Legacy **unmigrated other owners** могут оставаться до своего move; migrated owner целиком в target. No forwarding script wrappers | Domain strict + dependency strict no exemptions; current-format resource/snapshot whitelist + parser | Owner scripts + `.uid` + incoming ext_resources/tests/codec in one commit; rollback restores map/paths/version вместе |
| Direct cross-domain orchestration | 40 payload/handler ownership/target/result → 28 public manifest → 33 enforce before moves | Synchronous internal operations/stable domain API законны; не wrapper новой bus вокруг old flow | Damage/Commerce/Interaction/Customer/Quest contract fixtures: rejection, commit-before-fact, correlation, no cycles | Один cross-domain flow + handlers/callers/outcomes; old execution path удалён |
| Manual composition→Templates | 41 validated flat recipes + current scene engine pieces + ready/fixup → 42 Inspector | Native scene-owned physical components сохраняются как другая роль; migrated capability не добавляется и Trait, и old define_components. No permanent fallback | Two-instance isolation, placed/spawned parity, conflict/missing binding, partial rollback, load without reset | Одна capability family целиком со всеми scene/factory callers; compiler core + first migrated family coherent |
| Existing interaction→affordance/reservation | 43 existing counter/point + tokenized slot R, player/NPC callers; common execute/cancel | Old class-based branch удаляется для migrated affordance до DONE. Shared executor — один owner, no slot Entity wrapper | Exclusivity, stale token, cancellation/target loss/death, eligibility rejection, content provider negative fixtures | Один existing affordance + оба caller types + scene markers/data; optional new Sit/Sleep отдельно |
| Current NPC decisions→goal/action contract | 44 current schedules/jobs → priority/interrupt selection → native BT execution → owner result | Existing branches используют one action contract; no second BT/FSM leaf dispatcher; GOAP deferred | Goal priority, interruption/resume, timeout/target loss, no action restart, deterministic time/seed fixture | Selection + representative existing obligation + all affected tasks/resources; no mixed authority |
| Physical-root NPC→PHYSICAL/MACRO | 45A canonical Entity + physical child, full callers/DTO/save migration → 45B macro transitions → 45C acceptance | A остаётся fully PHYSICAL рабочим состоянием, не old/new authority. Interim transition adapters удалены в C; no DONE 45 до A–C | Health/inventory/link continuity, actor/body lookup, blocked spawn/pinning, no duplicate identity/outcome, save/load both modes | Каждый A/B/C coherent; A all NPC families/BT target adapters, B atomic transition, C strict cleanup; rollback целого slice |

Обычный Resource UID сохраняется при moves. Stable gameplay ID не вычисляется из нового path и не становится `ecs_id`/instance ID. Open editor scenes меняются через MCP либо закрываются пользователем перед raw edit; Ignore External Changes не используется. Phase 0 сцены не меняла.

### Persistence / reconstruct policy

| State | Сохранять / восстановить | Gate / owner |
| --- | --- | --- |
| Stable NPC/package/order/history/operation IDs | Сохранить domain IDs, monotonic sequences и uniqueness; authored objects получают explicit stable ID вместо target path | 04 contract, 28 map, 45A actor registry; duplicate/unresolved reject before mutation |
| Relationships | Durable inventory/storage/cargo/home/job links: stable endpoints + typed payload; restore после all endpoints | Two-pass restore, missing/dead endpoint policy, reverse caches rebuild; 25/45 |
| Scene/Definition/record script paths | Target authored references/UIDs + explicit safe asset/script whitelist; update loader prefix guards | 28–32; no old-path aliases. Changed serialized shape/path bumps schema; old format rejects |
| Templates/Traits/Profile | Immutable content identity/reference; runtime values отдельны, defaults применяются once before saved state | 41 composition version/current-format fixtures, no shared mutable containers |
| SpawnContext | Durable initial identity/bindings; transient Node/Entity handles не сериализуются | 41 endpoint fixup, 45 actor/body bridge derived |
| Schedule/obligations/travel | Selected obligation, authoritative completed facts, needed sequence и departure/arrival game ticks; authored schedule по reference | 47/44/45; Night reset policy сохраняет текущие закрытые promises/day semantics |
| Utility scores/GOAP/BT | Scores, future plan, BTPlayer/Blackboard/navigation/perception не сохраняются; reconstruct/reselect | 44; GOAP absent. Running session cancel/reset соответствует current Night contract |
| Smart reservations | Transient Night reservation не сохраняется; uninterrupted in-session representation transition сохраняет token или explicitly cancels before detach | 43/45; stale token не отменяет newer reservation, no replay of execution |
| Simulation representation | Identity, macro location/travel/action facts; body/BT/cache reconstruct. Mode может восстановиться из current world policy; no new person | 45 current-format save in both modes, safe placement/pinning/arrival idempotency |
| Time/randomness | World seed, game ticks, day/phase facts, needed per-decision sequence | 47 canonical seed bytes/order, save/reload decision fixture; physical lockstep не требуется |
| Physical/UI/transient state | Pose только по domain contract; velocities/hands/dialogue/modal/attacks/projectiles сохраняют current Night-reset semantics; UI не authority | 04/25/45; no serialization of live Object/RID/instance ID |
| Schema/version | Version bump при несовместимом persisted change; validate before live mutation; old/newer versions reject with reason | Нет converter/previous-version roundtrip requirement. User autosave не используется tests и не удаляется tooling |

### Validation coverage matrix

«План» означает required future acceptance, а не выполненный сейчас runtime check.

| Ошибка | Самый дешёвый доказательный gate | Owner / removal deadline |
| --- | --- | --- |
| Hidden Service tick / System wrapper | 03 layout-independent static smells + good/bad fixtures, broad-query/manual role review | 10 inventory; zero baseline 26/27 |
| Wrong canonical roles / legacy roots | Existing `validate_domain_structure.py` transition/strict + fixture tests | 28/32; strict не ожидается на current horizontal tree |
| Forbidden imports / class_name / cycles | 33 path/symbol owner index/public manifest fixtures; declared dynamic adapters review | Before moves; zero exemptions after 32 |
| Broken res paths / prefix guards / UIDs | Project structure scan + ResourceLoader/parser + new-format codec/snapshot fixture | 28–32, not only repository text replacement |
| Trait requires/provides/conflicts | Same 41 compiler used by Inspector/factory/Doctor; positive/negative fixtures | 41 before DONE, no second validator rules |
| Placed scene capabilities | Capability/node/export/animation/binding provider | 41/42, Smart Object fields 43 |
| Smart slots/executor | Missing slot/marker/token/executor negatives + reservation lifecycle | 43 before DONE |
| GOAP actions | Not in baseline; future evidence/task must add its provider/tests | DEFER, no empty mandatory gate |
| Stable ID uniqueness/endpoints | Content + save validation before registry/restore; duplicate spawn blocked before GECS ID-replacement behavior | 04/41/45, full scan 46 |
| Dialogue references/actions | Known title/resource/tag/action executor validation + existing dialogue regression | 42/43 provider, aggregation 46 |
| Schedule location/action | Resolve authored location + allowed action/time bounds, failure fixture | 44 provider, 46 aggregate |
| Animation/resource ranges | Scene capability names and Definition ranges, readable resource/field diagnostics | 41–44 providers, 46 full scan |
| Absent legacy architecture | Strict layout/dependency, closed inventory, no wrapper/duplicate authority review | 27 execution; 32 paths; 49 composition/AI/LOD |
| Why/rejection unobservable | Read-only reason/provenance snapshot fixture; bounded trace | 40–45 providers, 48 UI/owner QA |
| Broken roadmap/order/readiness | New `validate_refactoring_preflight.py` + 8 good/bad graph/gate fixtures | Phase 0; checks docs only, not runtime correctness |

Existing regressions usable at implementation: `test_customer_flow.gd`, `test_customer_timing.gd`, `test_district_population.gd`, `test_district_bt_lifecycle.gd`, `test_npc_attacks.gd`, `test_s_grab.gd`, `test_physical_slots.gd`, `test_wallet.gd`, `test_hunger.gd`, `test_refusal_quest.gd`, `test_save_data.gd`, `test_persistent_runtime.gd`, `test_district_snapshot.gd`. Actual new fixtures/CLI options are recorded by owning implementation task before it is DONE; nonexistent future commands are not reported as PASS.

### Milestone sizing

- 11–13: each scheduled responsibility coherent; no new compatibility bridge between tasks. Unmigrated outcome operation is a separate owner, not a duplicate runtime path.
- 21: slice held/push/slots/cargo by authority + all direct callers and physics tests; each temporary adapter removed within its slice.
- 29–31: whole owner per commit; incoming callers/references/codec move together; parent task DONE after all named owners.
- 41: compiler core + first working family, then complete each remaining representative family/all callers; 42 only Inspector ergonomics.
- 43/44: existing executor/obligation before variants; no new mechanic/GOAP demo requirement.
- 45: explicit A/B/C slices in owning task; body-cast/BT/scene/save migration is largest risk, included in A gate rather than hidden in B.
- 10/28 prepare concrete slice manifests using actual inventory; tasks can split locally when measured scope requires, preserving parents' full acceptance. No deferred wrapper survives declared DONE.

Each slice commits a runnable contract; no requirement to leave an invalid branch between files. Revert uses complete commit boundaries including paths/schema/tests, never force reset unrelated user edits.

### Existing project validation failures

`python utils/validate_project_structure.py` currently FAIL: 31 pre-existing diagnostics. One missing `truck_shift_gate_smoke.gd` reference and 30 missing Task state headings across six top-level R26 files. `git ls-files` and unchanged-file diff confirm these inputs were already tracked/unchanged. They are assigned to **03 infrastructure repair before runtime migration**, not silently allowlisted. Phase 0 does not restore a gameplay smoke script or edit unrelated R26 tasks. These failures do not invalidate the planning graph, but full project-structure PASS is mandatory before 10 and at subsequent acceptance.

## Validation result

- `python utils/validate_refactoring_preflight.py`: PASS (50 tasks, explicit dependencies/order/cycles/local links/encoding).
- `python -m unittest discover -s tests/tools -p test_validate_refactoring_preflight.py`: PASS, 8 tests.
- `python utils/validate_domain_structure.py`: PASS (transition).
- `python -m unittest discover -s tests/tools -p test_validate_domain_structure.py`: PASS, 4 tests.
- `python utils/validate_project_structure.py`: FAIL, known 31 pre-existing diagnostics assigned above.
- `git diff --check`: PASS.

Runtime/GUT/Godot parser/editor/rendered checks не запускались; project-owned `.gd` не изменялись. Validator fixtures — Python tooling tests, не gameplay implementation.

## Next

[00_05_preflight_readiness_gate.md](00_05_preflight_readiness_gate.md): второй полный review исправленного 50-task roadmap, scorecard и final verdict.
