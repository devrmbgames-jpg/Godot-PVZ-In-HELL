# Refactoring v2.62 — Code Style: NPC и Customers

Status: **IN_PROGRESS**

Зависимости: 61_style_ecs_core.md.

## Goal

Привести наиболее сложный orchestration/domain код NPC и Customers к human-first стилю после архитектурного разбиения.

## Scope

- project-owned NPC services/rules/solvers/presentation;
- Customer services/rules/presentation;
- NPC/Customer entities и related AI glue, если они не покрываются отдельной remaining task.

Scope: оставшиеся scripts в `content/domains/{npc,customers}/` по manifest задачи 61. Не повторять принятые ECS-role files.

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

## Current

163-script full style gate and actual CLI parser PASS. Native compilation is clean after
repairing two formatter precedence errors; no source-writer fallback is counted as PASS.
Profile regression:18 GUT suites,249 tests,2603 assertions PASS; stderr empty.
The pre-existing completion request cycle is repaired in
[completion request repair](npc_completion_dependency_cycle.md); strict dependency/project
structure PASS without validator exceptions. Source is saved through native MCP.
Final native compilation:163/163 checked, no diagnostics. Public data/API field names,
query/branch order, rays and physical authority remain intact. No rendered QA performed.
Final general CLI runner reports FAIL solely for shutdown retention after lifecycle-fixture
compilation; direct isolated compiler PASS,exit0. Preserve this as
KNOWN_ENGINE_LIMITATION / DEFERRED under owner policy; no blanket suppression added.
Independent immutable review REVIEW_PENDING; task62 remains IN_PROGRESS until triage.
