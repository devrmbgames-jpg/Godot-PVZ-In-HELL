# Refactoring v2.66 — финальная приёмка

Status: **PLANNED**

Зависимости: все предыдущие Refactoring v2 tasks завершены.

## Goal

Доказать, что после полного архитектурного и style рефакторинга проект сохранил поведение и получил устойчивые guardrails.

## Required checks

### Architecture

- service inventory 100% closed;
- architecture validator PASS без migration baseline;
- нет hidden System shell patterns;
- execution ordering review PASS;
- strict vertical-domain validation PASS;
- domain dependency validation PASS;
- Templates/Traits, Smart Objects, AI layering, Simulation LOD, Content Doctor и Game Time contracts прошли Phase 2 acceptance;
- UI остаётся Godot glue и не является gameplay authority;
- нет duplicate authority между Components/Relationships/services/BT/GOAP/UI.

### Code Style

- full project-owned formatter PASS;
- full linter PASS;
- line-length/naming conventions PASS;
- intentional ECS prefixes/suffixes не создают warning noise;
- addons/ не затронут.

### Godot

- parser/static diagnostics PASS;
- project structure PASS;
- профильные GUT suites всех затронутых крупных подсистем PASS;
- headless smoke основного gameplay flow PASS;
- save/write + restore smoke PASS;
- Windows QA build/smoke — если текущий стандарт проекта требует его для крупного milestone.

### Review

Провести финальный focused review отдельно от implementation. Каждый finding получает финальный статус.

## Owner QA

Составить один компактный qa_tasks/refactoring_v2.md только для того, что невозможно доказать автоматикой: feel, visual presentation, dialogue/UI flow и физическое ощущение управления.

## Completion

После PASS:
- durable архитектурные правила остаются в AGENTS.md / skills / content/ARCHITECTURE.md;
- временные migration baselines и obsolete wrappers удалены;
- task files могут быть удалены после сохранения нужной QA и контрактов согласно agent_tasks/README.md.
