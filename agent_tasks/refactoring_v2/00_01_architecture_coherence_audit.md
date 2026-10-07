# Refactoring v2.00.01 — architecture coherence audit

Status: **PLANNED**

Зависимости: нет.

Рекомендуемый reasoning: **xhigh**.

## Goal

Проверить весь `agent_tasks/refactoring_v2/*` как одну архитектурную программу до начала Phase 1/runtime refactor.

Цель — не переписать roadmap ради переписывания, а найти противоречия, пропуски, неверный порядок зависимостей и архитектурные решения, которые заставят позже переделывать уже выполненную migration.

Текущая target architecture в `docs/project_core_architecture_proposal.md` — **кандидат**, а не неприкосновенная спецификация. Если более простая или более удобная для Godot/GECS модель решает задачу лучше, roadmap и target design разрешено изменить.

## Read

Обязательно:
- `agent_tasks/refactoring_v2/README.md`;
- все `agent_tasks/refactoring_v2/*.md`;
- `docs/project_core_architecture_proposal.md`;
- `content/ARCHITECTURE.md`;
- `AGENTS.md`;
- `.agents/skills/refactoring/SKILL.md`;
- `.agents/skills/gecs-v8/SKILL.md`;
- `.agents/skills/gdscript-style/SKILL.md`.

Runtime/subsystem code читать выборочно только там, где надо доказать или опровергнуть реалистичность конкретного architectural assumption.

## Work

Построить dependency graph всего Refactoring v2 и проверить:

- ECS остаётся единственным authoritative gameplay state;
- Components / Relationships / Systems / Observers / Services имеют однозначный ownership;
- UI остаётся обычным Godot `Control`/glue и не втягивается в ECS;
- Templates/Traits не становятся вторым runtime model;
- placed и runtime-spawned Entity сходятся к одному runtime contract;
- vertical domains не конфликтуют с Godot scene/resource workflow;
- Commands/Events не создают скрытый global event bus;
- Schedule / Utility / GOAP / LimboAI не дублируют authority;
- Simulation LOD не требует второго NPC runtime;
- persistence, stable IDs и resource paths учтены до migrations, которые могут их сломать.

Для каждого task проверить:
- действительно ли все его prerequisites появляются раньше;
- не оставляет ли task permanent half-migration;
- можно ли завершить task как coherent milestone;
- достаточно ли Acceptance/Validation, чтобы доказать DONE.

## Allowed changes

Разрешено:
- менять roadmap;
- менять порядок;
- добавлять/удалять/дробить/объединять planning tasks;
- усиливать dependencies и acceptance gates;
- синхронизировать architecture docs/agent rules;
- добавлять architecture validators и их tests.

Запрещено:
- начинать runtime/gameplay refactor;
- переносить gameplay файлы;
- менять Systems/Components/Relationships/Services/Entities ради будущей migration.

## Output

Обновить roadmap так, чтобы dependency graph стал непротиворечивым.

Сохранить краткий список найденных архитектурных рисков внутри Task state/Current либо отдельного planning note, если findings слишком велики.

## Acceptance

- все Phase 0–3 tasks образуют понятный dependency graph;
- нет известной задачи, которая требует ещё не созданный foundation;
- нет очевидных permanent dual-architecture states;
- target design и roadmap не противоречат друг другу;
- найденные проблемы либо исправлены в плане, либо явно переданы следующей Phase 0 задаче.

## Validation

Documentation/validator-only. Runtime/gameplay tests не запускать.
