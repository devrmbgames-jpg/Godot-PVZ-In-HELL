# Refactoring v2.66 — финальная приёмка

Status: **IN_PROGRESS**

Зависимости: [65_style_remaining_code.md](../completed/refactoring_v2/65_style_remaining_code.md); все предыдущие Refactoring v2 tasks завершены.

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
- third-party addons/ не затронут; project-owned MCP companions проверены отдельно.

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

## Current checkpoint

Tasks60–65 and the native self-compilation defect are DONE after independent immutable
reviews. Current source checkpoint65: `287933e0c19c141ade715503063844fb7606a75f`.
Final acceptance is running; this task is not DONE before all mandatory gates and review.
Removed both empty architecture/dependency migration baselines and their allowance APIs:
normal/--strict validation always rejects lexical/access/cycle findings. Removed capture,
prune and architecture baseline CLI options fail closed; --strict remains compatible.
No execution migration wrapper remains. Persistence inventory accepts formatted multiline
flat Script lists without accepting expressions or changing schema10/golden inventory.
Inventory136/136 closure and execution ordering are accepted in tasks25/27/49;
Phase2 compiler/reservation/AI/participation/time/Doctor/UI contracts remain accepted.
Current full style980, strict architecture/domain/dependency, structure, persistence
inventory and tooling143 PASS; Content Doctor92 scenes/3 dialogues/0 errors/0 review PASS.
MCP Inspector regression9/9 PASS, authored_content_changed=false, Inspector restored.
Headless vertical_slice and customer_inspection PASS. Night write + fresh-process restore
PASS (`night_persistence-write-20261010-202715021`, `restore-20261010-202733311`).
Full112 GUT run:1641 loaded,1637 PASS,four FAIL; acceptance remains open. The independent
[fixture isolation defect](gut_definition_isolation.md) owns repair, ordered rerun and review.
Windows QA export PASS: `.export/windows/20261010-103204Z-4eca2941-refactoring-v2-final`,
menu/main-level120 frames each PASS, dirty owner worktree recorded, QA profile separate.
Independent final source review base `287933e0c19c141ade715503063844fb7606a75f` to
`4eca294128c4acd78f4d53cf0ec1b4616c970bcc`: ARCHITECTURE/STYLE PASS, no material
findings; reviewer VALIDATION NOT_RUN. Startup ordering/UI/zero-debt detection reviewed.
Subjective QA is consolidated in qa_tasks/refactoring_v2.md; owner acceptance of both
Inspector / Direct Traits and Gameplay Debugger2026-10-10 remains authoritative.
