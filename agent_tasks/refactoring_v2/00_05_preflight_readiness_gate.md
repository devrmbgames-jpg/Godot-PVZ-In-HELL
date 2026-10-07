# Refactoring v2.00.05 — preflight readiness gate

Status: **DONE**

Result: **READY_FOR_IMPLEMENTATION**

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

## Current — второй полный review 2026-10-07

00_01 → 00_02 → 00_03 → 00_04 завершены последовательно до gate. Повторно проверены исправленный 50-task roadmap, dependencies/acceptance, final proposal и соответствие AGENTS/skills/runtime contracts. Phase 1–3 tasks остаются PLANNED; изменения их файлов — исправленный план, не выполнение Work.

### Final review matrix

| Area | Verdict / evidence |
| --- | --- |
| Dependency graph | PASS: все tasks ровно один раз, 40 до moves, 33 до первого move, 47 до AI/LOD, 26 не зависит от поздней Phase 2B/C; automated order/cycle/link check |
| Authoritative ownership | PASS: C/R domain state, Systems cadence/query, Observers reactions, Services synchronous operations; Godot physical authority отдельно |
| UI / scenes | PASS target: Control glue вне ECS, visible placed scene, read-only preview; shared Inspector/headless rules |
| Authoring cost | PASS target: ordinary variant 2–4 local edits, reused Template/Profile; new mechanic честно требует code |
| Debugging / agent context | PASS target: owner path/public manifest/local regression, early reason/source providers, bounded trace, native BT inspector |
| Overengineering | PASS: GOAP/4 tiers/Utility framework deferred; inheritance/hooks/global bus/default slot Entity rejected; no placeholder layer |
| Vertical boundaries | PASS target: whole ownership + references/UIDs/loader/tooling; class_name/data contracts по manifest; checker не обещает semantics |
| Commands/Events | PASS target: targeted transport, immutable payload, one handler, accepted vs committed result; ordering/cycle fixtures 40 |
| Templates/Traits | PASS target: flat recipes, isolation, conflict/override/restore policy, ready/fixup, placed pre-registration gate |
| Smart Objects | PASS target: existing executor, actor→object slot/token, serialized acquire/cancel, stale-token/loss/conflict fixtures |
| AI | PASS target: schedule obligations, bounded selection, native LimboAI; cancel/resume/target loss, no duplicate authority |
| Representation | PASS target: canonical Entity, physical child/DTO separation, two modes/cadence, A/B/C gates, active-session pinning |
| Time/randomness | PASS target: early game ticks, day/phase policy, canonical seed encoding/sequence/order; no physics lockstep |
| Persistence | PASS target: new-format identity/links/safe restore/schema rejection; old saves не мигрируются по решению владельца |
| Validators | PASS preflight: graph/links/encoding + 10 fixtures, transition domain + 4 fixtures. Global structure FAIL recorded below |
| Milestone sizing | PASS plan: responsibility/family/whole-owner commits, adapters removed before declared DONE; 45A/B/C explicit largest risk |
| Acceptance | PASS plan: Phase 1 baseline repair before runtime, execution 27, strict layout/dependency 32/33, core 49, style coverage 61–65, final 66 |

### Findings исправлены в этом повторном review

1. Validation внутри `_initialize` слишком поздно для GECS ID-collision replacement. В 41/proposal закреплён project-owned placed World/bootstrap: context/recipes/IDs/endpoints **до** pinned registration once, затем fixup/ready и first simulation. Factory использует тот же gate; addons read-only.
2. Trader demo в 41 могла требовать deferred new mechanic. Mandatory example — existing resident/customer; Trader optional при готовой capability.
3. Stale mandatory GOAP references, inconsistent reservation name и повторяющиеся proposal subsection IDs исправлены; time/seed синхронизирован с 47.
4. Public data contracts разрешены из owning component/profile/trait paths по manifest без forwarding copy. Read access не передаёт writer authority.
5. Headless placed/spawned capability contract отделён от subjective Inspector QA; visual pass не заявлен.
6. Preflight fixtures дополнены escaped repository link и missing final result; итог 10 tests.

### Required scorecard

Оценки относятся к **target plan**, не текущей реализации/playtest. 8 = ownership/workflow определены и gates/QA owners есть; 9 = особенно ясная граница без outstanding global design choice. 10 не ставится до практического применения.

| Category | Score | Evidence / limitation |
| --- | --- | --- |
| Programmer UX | 8/10 | Canonical path, query/deps, contracts, local fixtures; 45A требует тщательного caller review |
| Designer UX | 8/10 | Visible scene, inline Resources, named bindings; ergonomics — owner QA 42 |
| Debugging UX | 8/10 | Early reason snapshots, bounded trace/native BT; actual view — 48 |
| AI-agent UX | 9/10 | Ordered tasks, owner paths, bounded regression, graph/dependency gates |
| Content scalability | 8/10 | Existing variant data-driven, reused executor/provider; new mechanics требуют code |
| Architecture clarity | 9/10 | One domain authority, physics exception, two modes, no hidden scheduler/bus/planner state |

### Freedom pass / decision

Да: с нуля для Godot + GECS + LimboAI + Dialogue Manager выбрали бы эту bounded baseline. Retained layers решают concrete authoring/scheduling/absence/debug problems; deferred layers не нужны для acceptance. Новая механика имеет owner/capability/provider; existing variant обычно меняет scene/Profile/Definitions/bindings. Implementation details решаются локально в task без пересмотра всего graph.

**READY_FOR_IMPLEMENTATION** разрешает следующий Phase 1 contract/guardrail pass. Это не runtime acceptance и не утверждение, что текущий проект уже проходит все checks. Unresolved architectural blockers нет; infrastructure debt имеет repair owner до runtime migration.

### Existing debt / future gates

- Project structure сейчас FAIL: 31 pre-existing diagnostics, missing smoke script reference + metadata шести R26 tasks. Owner **03**, full PASS до 10; Phase 0 не исправляла эти файлы и не ослабила validator. Debt не требует architectural redesign и не блокирует начало contract Phase 1.
- Highest implementation risk — 45A physical-root/identity separation. All callers/BT/scene/save adapters входят в coherent slice; no duplicate actor/record authority. Failure удерживает 45 unfinished, не легализует permanent adapter.
- Parser/GUT/smoke/content/strict runtime gates ещё не выполнялись; обязательны в owning implementation tasks. Subjective Inspector/AI/feel/debugger QA — 42/44/45/48/66, не автоматический PASS.

## Validation result

- `python utils/validate_refactoring_preflight.py --require-gate`: PASS.
- `python -m unittest discover -s tests/tools -p test_validate_refactoring_preflight.py`: PASS, 10 tests.
- `python utils/validate_domain_structure.py`: PASS (transition).
- `python -m unittest discover -s tests/tools -p test_validate_domain_structure.py`: PASS, 4 tests.
- `python utils/validate_project_structure.py`: FAIL, known 31 pre-existing diagnostics assigned 03; no new Phase 0 diagnostics.
- `git diff --check`: PASS.
- Scope: no project-owned `.gd`/`.tscn` edits; Phase 1–3 PLANNED; unrelated config/addon edits preserved.

Godot parser/gameplay/GUT/rendered checks не запускались: изменены planning docs и Python validator/tests. Primary Mass/Flecs references проверены в 00_03, GECS API — local source.

## Next

[01_architecture_contract.md](01_architecture_contract.md) — отдельный следующий рабочий запрос. **Не начата в этом pass.**
