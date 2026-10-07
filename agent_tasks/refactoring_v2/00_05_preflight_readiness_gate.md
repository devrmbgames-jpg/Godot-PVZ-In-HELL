# Refactoring v2.00.05 — preflight readiness gate

Status: **DONE**

Result: **READY_FOR_IMPLEMENTATION**

Blockers: NONE

Зависимости:
- [00_01_architecture_coherence_audit.md](00_01_architecture_coherence_audit.md)
- [00_02_usability_authoring_audit.md](00_02_usability_authoring_audit.md)
- [00_03_simplification_reference_audit.md](00_03_simplification_reference_audit.md)
- [00_04_migration_persistence_validation_audit.md](00_04_migration_persistence_validation_audit.md)

Рекомендуемый reasoning: **xhigh**.

## Goal

Провести второй полный review уже исправленного roadmap и разрешить или запретить начало Phase 1.

Это отдельный gate. Он не реализует gameplay/runtime.

## Final review

Ещё раз проверить:
- dependency graph;
- authoritative ownership;
- usability;
- content-authoring cost;
- debugging/observability;
- AI-agent context cost;
- overengineering;
- vertical-domain boundaries;
- Commands/Events boundaries;
- Templates/Traits;
- scene-first visual authoring;
- Smart Objects;
- Schedule/Utility/GOAP/LimboAI;
- Simulation LOD;
- time/randomness;
- persistence;
- validators;
- milestone sizing;
- acceptance criteria.

Провести финальный freedom pass:

> Если бы сегодня это ядро проектировалось с нуля специально для Godot + GECS + LimboAI + Dialogue Manager и нашего workflow — сделали бы мы его именно так?

Если нет — исправить roadmap/docs и повторить review.

## Required scorecard

В финальном отчёте дать:

```text
Programmer UX:        X/10
Designer UX:          X/10
Debugging UX:         X/10
AI-agent UX:          X/10
Content scalability:  X/10
Architecture clarity: X/10
```

Для оценки ниже 8/10 обязательно объяснить причину и либо исправить roadmap, либо явно принять компромисс.

## READY criteria

Разрешён только один из двух результатов:

`READY_FOR_IMPLEMENTATION`

или

`NOT_READY_FOR_IMPLEMENTATION`.

`READY_FOR_IMPLEMENTATION` допустим только если:
- dependency graph непротиворечив;
- нет известных half-migration traps;
- нет очевидного неоправданного overengineering;
- обычный content authoring не требует избыточной ceremony;
- Phase 1–2 имеют доказуемые acceptance gates;
- target architecture согласована между roadmap/docs/skills;
- новая механика имеет понятное место;
- новая вариация существующей механики создаётся преимущественно данными;
- дальнейшие решения можно принимать локально внутри task без пересмотра всего roadmap.

## Completion

Если результат `READY_FOR_IMPLEMENTATION`:
- обновить Status этой задачи на DONE;
- в `agent_tasks/refactoring_v2/README.md` зафиксировать readiness;
- следующим действием назначить `01_architecture_contract.md`;
- **не начинать 01 в том же planning pass**.

Если `NOT_READY_FOR_IMPLEMENTATION`:
- оставить конкретные blockers и next planning action;
- Phase 1 не начинать.

## Validation

Documentation/validator-only. Godot gameplay/runtime implementation и broad gameplay tests не запускать.

## Current — повторный полный readiness review 2026-10-07

00_01 → 00_02 → 00_03 → 00_04 завершены строго последовательно с отдельными commits 0485062e, 56482e6c, f2c81333, 35ce7953. Этот gate — отдельный второй review исправленного плана в новом pass, не повтор checkbox-отчёта первого прохода. Повторно сопоставлены 50-task roadmap, contracts/scopes/acceptance, target proposal, AGENTS и relevant skills с actual GECS/bootstrap/NPC/Dialogue/save contracts. Phase 1–3 PLANNED; runtime migration не начата.

### Final review matrix

| Area | Verdict / evidence |
| --- | --- |
| Dependencies | PASS: inventory 10 → typed foundation 40 → execution 11–27 → layout 28/transition guard 33 → whole-owner moves 29–32 → time/seed 47 → composition/authoring/AI/LOD 41–45 → Doctor/debugger/acceptance 46/48/49 → bulk style 60–66 |
| ECS authority | PASS target: C/R and owned aggregate metadata; single writer per field; Godot owns physical transform/velocity; Blackboard/UI/Dialogue/cache derived only |
| Execution ownership | PASS target: query/time/cadence in Systems, reactions in Observers, synchronous operations in Services; callback solvers stay engine-owned; no generic service dispatcher or mega-System |
| Commands/facts | PASS target: targeted GECS or synchronous API, explicit accepted/pending/committed result, immutable payload, one command handler; distinct idempotent fact consumers; PER_GROUP flush/reentrancy tests |
| Vertical boundaries | PASS target: 14 owners, population/schedule under npc; edge/symbol/read/write manifest; actual implementation cycles fail; reciprocal leaf data contracts alone require no wrappers |
| Global glue | PASS target: UI/resource/context opening and cross-owner composition outside domains; domains expose narrow session/action API, no domain→UI/shared→domain/domain→persistence imports |
| Scene-first authoring | PASS target: real visible physical-root scenes, native declarative recipes; optional inline Template, Profile/bindings/ID provenance; explicit repair; no empty Template asset or scene back-reference |
| Templates/Traits | PASS target: flat pure recipes, each provider once, nested mutable isolation, pre-registration ID checks; closed installer manifest/all families before DONE, no manual+Trait double setup |
| Bootstrap/restore | PASS target: explicit World context before registration; ECS.world setter does not run early; setup/on_ready/Observers passive until startup overlay/fixup/ready; failed construction publishes no gameplay effects |
| Content workflow | PASS target: six walkthroughs and two-variant cookbook/fixtures; existing Trader/Quest configuration author-selectable; new objective/executor/attack kind is honestly a new mechanic |
| Smart Objects | PASS target: marker/slot_id + actor→object R/token; occupancy derived; atomic deferred acquire checks at execution; queued contenders, stale incarnation/load/cancel/loss fixtures |
| AI | PASS target: obligations/bounded selection/native LimboAI; one ECS action lifecycle, cancel/resume/target-loss tests; pure optional scoring; GOAP deferred |
| AI budgeting | PASS target: per-responsibility work-unit caps/fair cursor/coalesced wakes; urgent cancellation, burst/no-starvation/max-wait diagnostics; no additional scheduler or performance promise from Hz examples |
| Simulation LOD | PASS target: ACTIVE/DORMANT keeps allocated physical roots; one participation writer, dormant actors still resolvable, current absent-phase semantics; safe reactivation/pinning/latency tests; no camera-driven disappearance |
| Time/randomness | PASS target: elapsed integer ticks/quantum/remainder distinct from player calendar; pause/skip/Night policy; persisted decision sequence/canonical seed/output fixture; no physics lockstep |
| Stable IDs | PASS target: 04 specifies baseline, 25 implements stable placed IDs/removes path matching before moves; world/local vs spawned/content/operation namespaces; node rename/reparent fixture |
| Persistence | PASS target: Night prepared-Morning quiescent snapshot, retry once semantics, version rejection, defaults→save overlay→links→cache→ready; no old-save migration/mid-action checkpoint or generic undo |
| Validation/observability | PASS preflight tooling; future owner providers start at 19/24/40–45, Doctor46 aggregates and Debugger48 views; static guard limits/write semantics acknowledged |
| Milestone closure | PASS plan: responsibility/whole-owner/family slices with all callers, closed manifests and removal before DONE; 45A participation/B transition/C save+cost replaces speculative shell migration |
| Style/acceptance | PASS plan: changed/new code follows current style/parser throughout; bulk toolchain/pass after49; coverage manifest61–65, final66; no deferred features silently added to acceptance |

### Findings исправлены в final review

1. **Stable-ID implementation gap.** 04 была contract-only, а path moves уже рассчитывали на durable placed IDs. Runtime migration всех authored IDs и removal `scene/<path>`/NodePath matching назначены 25, до 28–32; no aliases, explicit schema bump/new-format fixtures.
2. **Deferred reservation race.** Enqueue-time check недостаточен: acquire проверяет eligibility/exclusivity в момент mutation. Token включает world/session + object incarnation + sequence; callbacks до load/recreate не отменяют новый reservation. Acceptance 43 усилена.
3. **Coarse domain DAG overengineering.** Blanket запрет взаимных публичных data/query references заставил бы создавать shared copies/wrappers. 28/33/proposal различают actual file/symbol implementation cycles и aggregate domain graph; declared leaf contract references допустимы при single writer и отсутствии actual cycle. Behavioral public API cycle всё ещё FAIL.
4. **Domain→UI back edge.** Одного переноса ctx недостаточно, если domain start() продолжает его создавать. Panel/resource/context construction явно moves into existing global UI/glue; domain retains begin/end/eligibility/outcomes. Scope 29 закрывает callers/hierarchy одновременно.
5. **Stale scope wording.** 26 больше не исключает early40 из prerequisites по numerical range; optional Template consistent throughout proposal; new/changed code style/parser действует до bulk Phase3. Native scene recipes являются target provider, no empty asset/fallback.
6. **LOD behavior scope.** Street NPC не исчезает из-за camera culling, dormant timers следуют existing absence semantics; retained-body memory and tuning measurements explicit, no speculative offscreen gameplay.

После этих fixes снова сопоставлены затронутые scopes 25/26/28/29/33/41/43/45 с whole roadmap/target и prerequisites. Ни один fix не требует нового runtime framework или Phase 0 gameplay edits.

### Freedom pass

С нуля выбрали бы эту исправленную baseline: native Godot scene/component authoring для простых объектов, flat Traits для повторяемых capability bundles, Profile для variants, один prepare/validate path и explicit construction gate GECS. Removing Templates entirely would restore duplicated multi-capability wiring; forcing them onto every simple object would add ceremony. Optional composition with one validated provider resolves both cases.

Existing population record aggregate and physical roots fit нынешний Godot workflow лучше обязательного actor shell. Dormancy/budget решают processing cost; память не исчезает и измеряется в 45. Separate district ownership, coarse-DAG wrappers, generic action/quest interpreter, bus, planner and custom RNG do not justify their cost. NPC и Customer remain separate because personality/behavior and visit/package/settlement have distinct lifecycle/regression owners; known inheritance/context back edges receive concrete decomposition scope.

Новая механика получает owner, data/recipe contract, System/Observer only for behavior, validator/diagnostic provider и focused fixture. Вариация существующей mechanics меняет scene/Profile/Definition/Dialogue/bindings; новый ET/script/global registry edit не требуется. Debug snapshots explain source/rejection/cancel/result with bounded trace/native BT inspector. Temporary adapter cannot survive its owned slice or task DONE.

### Required scorecard

Оценки относятся к target plan, не текущему runtime или visual playtest. 8 — удобный explicit workflow с доказуемыми gates и оставшейся practical QA; 9 — особенно ясная ownership/context boundary. 10 до production usage не ставится.

| Category | Score | Evidence / limitation |
| --- | --- | --- |
| Programmer UX | 8/10 | Early typed APIs, local ownership/fixtures, no shell or wrapper tax; bootstrap/domain decomposition still require careful implementation |
| Designer UX | 8/10 | Visible scenes, inline optional Templates, local Profiles/bindings and two-variant gates; actual Inspector ergonomics await42 QA |
| Debugging UX | 8/10 | Early reason/provenance/result snapshots, fairness counters and native BT inspector; view usability awaits48 QA |
| AI-agent UX | 9/10 | Ordered bounded tasks, owner/contract manifest, staged/commit scope checks and explicit completion/removal gates |
| Content scalability | 8/10 | Variants reuse recipes/executors without code; new mechanics require explicit owner; retained body budget measured at45 |
| Architecture clarity | 9/10 | Per-field C/R/aggregate authority, physical exception, explicit startup/result/time/session contracts; no competing AI/state framework |

### Readiness and open questions

Architectural blockers отсутствуют. Next — 01 contract/guardrail pass отдельным запросом; Phase 1 здесь не начата. Local implementation choices имеют owners: quantum/hash framing/output vectors —47, concrete public symbol/slice map —10/28, Inspector details —42, actual AI work caps/population costs —44/45. Эти решения не требуют нового global design. Body detach/GOAP/macro travel требуют отдельного evidence-driven feature decision и не являются обязательным acceptance.

Known infrastructure debt: project structure FAIL with 31 unchanged errors (missing smoke-script reference and R26 metadata). Repair owner03, mandatory full PASS before10. Это blocker runtime migration, но не Phase1 documentation/guardrail work; validator не ослаблен. Subjective Inspector/AI/feel/debugger QA assigned42/44/45/48/66. No visual/runtime acceptance is claimed here.

## Validation result

- `python utils/validate_refactoring_preflight.py --require-gate`: PASS; graph/links/encoding, five DONE audits, all future tasks PLANNED, unique final result/README/proposal/next task/blockers/six scores.
- `python -m unittest discover -s tests/tools -p test_validate_refactoring_preflight.py`: PASS, 20 tests in 00_04; no validator/test changes in this final review.
- `python utils/validate_domain_structure.py`: PASS (transition); 4 fixture tests PASS in00_04, unchanged tooling thereafter.
- Commit footprint of preceding four audits plus staged final-review changes: PASS via `--phase0-commit`/`--check-staged-scope`; unrelated unstaged config/addon edits preserved.
- `python utils/validate_project_structure.py`: FAIL, known31 unchanged diagnostics verified in00_04 and assigned03; no new tooling/structure contract added afterward.
- `git diff --check`: PASS.

Godot/parser/GUT/gameplay/rendered checks не запускались: runtime `.gd`/`.tscn` не изменялись. Existing Python tooling fixtures ran; future behavioral/strict/content acceptance remains mandatory in implementation owners. Mass/Flecs references opened in00_03; actual APIs verified from local pinned GECS/Dialogue source/skills.

## Next

[01_architecture_contract.md](01_architecture_contract.md) — следующий отдельный рабочий запрос. **Остановиться; не начинать Phase 1 в этой сессии.**
