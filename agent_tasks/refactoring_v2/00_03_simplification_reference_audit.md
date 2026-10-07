# Refactoring v2.00.03 — simplification, overengineering и reference audit

Status: **DONE**

Зависимости: [00_02_usability_authoring_audit.md](00_02_usability_authoring_audit.md).

Рекомендуемый reasoning: **xhigh**.

## Goal

Провести отдельный adversarial review всех новых framework/layers и убрать архитектуру, которая существует только потому, что она "правильная", модная или похожа на чужой engine.

## Core question

Для каждого крупного слоя спросить:

1. Какую реальную проблему проекта он решает?
2. Почему существующий механизм не решает её достаточно хорошо?
3. Сколько новых concepts/API/files он добавляет?
4. Сколько boilerplate потребуется на один новый content item?
5. Можно ли получить 80–90% пользы существенно проще?
6. Как это дебажить?
7. Как валидировать?
8. Кто основной пользователь: programmer, designer/editor или runtime?
9. Не появляется ли второй source of truth?
10. Насколько сложно удалить/заменить слой позже?

## Explicitly challenge

Не считать обязательными только потому, что они уже записаны:
- GOAP;
- Utility layer;
- полный Trait framework;
- Smart Objects в текущем виде;
- четыре Simulation LOD;
- конкретное разбиение domains;
- общий Commands/Events abstraction;
- Template inheritance;
- отдельные authoring/compiler classes.

Разрешено предложить более простой механизм.

## External references

Использовать Unreal Mass/Flecs/другие зрелые ECS/data-oriented systems как источник опыта, а не blueprint.

Для каждой borrowed idea проверить:

```text
Какая проблема решается в reference?
↓
Есть ли та же проблема у нас?
↓
Подходит ли решение для Godot + GECS?
↓
Можно ли реализовать проще?
↓
Как это ощущается в ежедневной работе?
```

Unreal Mass особенно релевантен как reference для:
- Entity Templates / Traits;
- processors vs observers;
- deferred structural changes;
- Simulation/Representation LOD;
- signals/event-driven work;
- Smart Object integration.

Не переносить Unreal-specific lifecycle/API/complexity без собственной причины.

## Decision format

Для каждого существенного изменения:

```text
Problem
Current proposed solution
Suggested improvement
Why it is better for this project
Complexity cost
Migration impact
Decision: ADOPT / REJECT / DEFER
```

## Freedom pass

В конце задать вопрос:

> Если бы сегодня это ядро проектировалось с нуля специально для Godot + GECS + LimboAI + Dialogue Manager и нашего workflow — сделали бы мы его именно так?

Искать возможность:
- убрать слой;
- объединить похожие механизмы;
- заменить runtime abstraction на authoring-time compilation;
- улучшить Inspector/editor tooling;
- заменить documentation-only rule дешёвым validator;
- уменьшить число mandatory Resources;
- сократить число мест, редактируемых для нового content;
- улучшить observability;
- уменьшить AI-agent context footprint.

## Acceptance

- нет известного architecture layer без конкретной project-specific причины;
- borrowed ideas имеют явную ссылку/обоснование и адаптированы под Godot/GECS;
- overengineering либо удалён, либо сознательно принят с объяснением;
- roadmap отражает принятые simplifications/improvements.

## Validation

Planning/docs/validator-only. Runtime implementation запрещён.

## Current — повторный adversarial review 2026-10-07

Adversarial review выполнен после отдельного commit 00_02. Учитываются actual physical-root freeze/hide/collision disable, C_District.people и schedule service, current LimboAI/actions/Dialogue. Costs — estimate concepts/authoring edits, не measured code size/performance. Каждая строка содержит Problem, Current proposed solution, Suggested improvement, Why, Complexity cost, Migration impact, Decision. Mass/Flecs primary pages повторно открыты; pinned GECS source важнее reference API.

| Layer / пользователь | Problem | Current proposal | Suggested improvement / Why | Complexity cost | Migration impact | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| GOAP / runtime | Альтернативные macro paths текущими jobs не доказаны | Mandatory planner в 44/49 | Existing obligations + LimboAI; planner только при evidence, меньше search/state/debug burden | Сейчас 0 planner types/API | Убрать mandatory GOAP acceptance, no placeholder | DEFER |
| Utility / programmer | Competing goals/thrashing | Separate layer каждого NPC | Bounded priorities; pure scoring/hysteresis только при need | 1 selection owner, optional helper | 44 сохраняет local BT hierarchy | ADOPT helper; DEFER framework |
| Traits / author | Repeated capability wiring | Full framework, 6 mandatory classes | Flat recipes + Profiles; no per-item script, compile conflicts | 2 authored types, transient plan, compile/factory operations | 41 migrates families/callers целиком | ADOPT minimal |
| Template inheritance / author | Reuse variants | Parent Templates possible | Godot inherited scenes + flat Traits/Profile; explicit merge | 0 parent graph | No hidden override order | REJECT |
| Compiler classes / programmer | Invalid config before registration | Mandatory context/compiler/factory hierarchy | One typed operation, class только для real boundary | No mandatory wrappers | Extend factory, GECS ready barrier | ADOPT roles; REJECT six-class mandate |
| Arbitrary hooks / runtime | Scene setup | Trait setup hook | Declarative requirement + narrow engine adapter | 1 adapter per new capability | No compiler side effects; restore idempotency | REJECT arbitrary hooks |
| Smart Objects / designer | Shared eligibility/reservation/cancel | Universal framework + Chair/Bed demos | Existing executor + affordance data, player/NPC same contract | Definition + relationship token + adapter; 0 scripts per variant | 43 replaces existing path; Sit/Sleep optional | ADOPT bounded |
| Slot Entity / author | Slot exclusivity | Entity per slot | slot_id/token on actor→object R, scene marker; fewer objects | No extra Entity/wrapper | Slot invalidation в 43 | REJECT default slot Entity |
| LOD / runtime | Inactive NPC processing cost | Forced lightweight Entity + detachable body, then four tiers | ACTIVE/DORMANT with retained physical root; existing absent-phase lifecycle + cadence | One participation owner, no new actor/body lookup layer | 45A unify participation; B safe transitions; C save/performance | ADOPT dormancy; DEFER detach/travel/four/aggregate |
| NpcRecord / programmer | Per-field metadata/actor authority unclear | Make every record DTO and migrate all state to new Entity shell | Existing aggregate is ECS state; document single writer and immutable mirrors/history | Authority map; no second live store | 45 proves metadata/HP/inventory/link continuity, no root migration | ADOPT aggregate; REJECT treating nested Resource as duplicate by default |
| District domain / agent | NPC/population mutual dependencies | Separate district + npc owners | Merge population/schedule/config into npc; same personalities/lifecycle | 14 owners instead of 15 | 29 owns all NPC/population files; 31 no district move | REJECT separate district boundary |
| Runtime dependency cycles / programmer | Public visibility hides bidirectional coupling | Public manifest alone | Acyclic allowed edges + public symbols; existing cross-owner contexts in global composition | No generic plugin/port registry | 28 matrix, 33 graph; NPC cannot import customers, domains cannot import persistence | ADOPT directed contracts |
| Scene selector / designer | Cycle/duplicate scene source | Template.default_scene + scene.Template + Profile.scene | Factory(scene, context), Template on scene only | Remove field, 0 new wrappers | 41 all selectors/callers, 42 cycle fixture | REJECT default_scene back-reference |
| Quest/Dialogue / author | No-code claim lacks content binding | Hardcoded Quest Definition, unconstrained ctx | Existing quest configuration + narrow typed read/action/session result | No Quest DSL/global registry | 19 variants, 40 replay/late-await, 46 validation | ADOPT bounded existing mechanic |
| Commands/Events / debugger | Hidden orchestration, intent vs fact | Potential global bus/framework | Existing targeted GECS + synchronous API, immutable trace | Types only per useful boundary; no dispatcher | 40 before 11; internal sync operation need not create two payload classes | ADOPT contracts; REJECT bus |
| Time/randomness / runtime | Mixed clocks/random decisions | Foundation after AI | 47 before 41, explicit clocks/seed, no physics lockstep | Clock/seed operation + needed counters | Preserve day semantics, version changed save shape | ADOPT |
| Content Doctor / author | Silent invalid configs | Giant late validator | Owning providers + aggregate CLI 46 | One result schema; reuse Inspector rules | 41–45 negative fixtures before DONE | ADOPT incremental |
| Debugger / debugger | Why/failure inaccessible | Late giant view | Early snapshots, bounded selected trace, native BT inspector | Providers + 1 view | 40–45 providers, 48 UI | ADOPT |
| AI budget / runtime | Burst/repath work and starvation | Frequency numbers without fairness proof | Per-responsibility work caps, stable fair cursor/coalesced wakes, urgent cancel | Existing Systems/queues + bounded counters | 44 burst/max-wait fixtures; no global AI scheduler | ADOPT bounded budgeting |
| Old saves / owner | Early unfinished project | Initially preserve schema 2 | Owner excludes conversion: reject old version safely | 0 alias/converter | Version bump/current-format tests; no user-file deletion | REJECT migration |

### Borrowed ideas / reference audit

Первичные источники открыты 2026-10-07; это conceptual references, не API проекта:

- [Mass Entity](https://dev.epicgames.com/documentation/unreal-engine/overview-of-mass-entity-in-unreal-engine?lang=en-US): composition/Traits и deferred structural changes полезны для repeated wiring; Template inheritance не переносится, command buffer — pinned GECS.
- [Mass Gameplay](https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-mass-gameplay-in-unreal-engine): representation/simulation separation, signals и capability integration адаптированы; четыре tiers, StateTree и Unreal lifecycle не перенесены.
- [Flecs Observers](https://www.flecs.dev/flecs/ObserversManual.html): scheduled/reactive distinction и explicit notification semantics полезны; actual delivery/flush — local GECS authority. No Flecs dependency.

Smart Object integration reference — доступный Gameplay overview; project uses scene markers/Relationships/owning operation, no Unreal runtime API. Cadence vs representation distinction полезна для independent budgeting; zero-body representation itself deferred because current population/memory need is unmeasured. Deferred mutations borrow safety, not Mass chunk/EntityManager replacement. Signals become coalesced targeted wakes, not another bus.

### Freedom pass

Первый план не прошёл бы freedom pass: mandatory detached body and separate district owner imposed two expensive migrations without demonstrated benefit. Исправленный target — real physical scenes, flat recipes/Profile, ECS-owned aggregate metadata, active/dormant processing, query-visible execution, directed typed contracts and native BT hierarchy. Template scene cycle, global bus/Quest DSL/planner/extra scheduler removed/deferred. Memory from retained dormant bodies is explicit tradeoff, not a hidden performance claim; measured need can justify a separate future detach milestone.

## Validation result

Proposal, 29/31/33/41/44–49 и README синхронизированы с ADOPT/REJECT/DEFER. Core acceptance не требует deferred features. `python utils/validate_refactoring_preflight.py`: PASS. `git diff --check`: PASS. Pending 00_04/05 reports первого прохода ещё не authoritative; обновляются последовательно. Runtime/Godot/GUT не запускались.

## Next

[00_04_migration_persistence_validation_audit.md](00_04_migration_persistence_validation_audit.md): slices, current-format persistence, validator coverage и removal gates.
