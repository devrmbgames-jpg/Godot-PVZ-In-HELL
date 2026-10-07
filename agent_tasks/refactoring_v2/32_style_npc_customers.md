# Refactoring v2.32 — Code Style: NPC и Customers

Status: **PLANNED**

Зависимости: 31_style_ecs_core.md.

## Goal

Привести наиболее сложный orchestration/domain код NPC и Customers к human-first стилю после архитектурного разбиения.

## Scope

- project-owned NPC services/rules/solvers/presentation;
- Customer services/rules/presentation;
- NPC/Customer entities и related AI glue, если они не покрываются отдельной remaining task.

## Extra focus

Особенно улучшить читаемость:
- route/perception calculations;
- customer visit state transitions;
- ECS/Relationship lookup;
- raycasts/visibility;
- multi-step settlement/outcome blocks;
- LimboAI adapter logic.

Сложные блоки должны иметь короткий intent comment, если назначение нельзя понять из имён и структуры.

## Acceptance

Style gate PASS по NPC/Customer scope.
Нет vague data/result/tmp там, где роль известна.
Нет искусственного сокращения имён ради 100 chars.

## Validation

Style gate + parser + узкая NPC/Customer regression при semantic edits.
