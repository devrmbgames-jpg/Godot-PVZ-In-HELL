# Refactoring v2.00.05 — preflight readiness gate

Status: **PLANNED**

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
