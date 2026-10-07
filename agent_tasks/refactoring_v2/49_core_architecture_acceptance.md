# Refactoring v2.49 — core architecture acceptance

Status: **PLANNED**

Зависимости: [48_gameplay_debugger.md](48_gameplay_debugger.md); все Phase 2 tasks завершены, strict rerun 32/33 PASS.

## Goal

Зафиксировать стабильное ядро до массового Code Style pass.

## Required acceptance

- architecture service/execution validator PASS;
- strict domain validator PASS;
- domain dependency validator PASS;
- typed Commands/Events core flows PASS;
- Templates/Traits representative composition PASS;
- content authoring cookbook и headless fixtures: два existing NPC/Trader/combat/object/quest-dialogue variants + новый level с reused mechanics; no runtime script/global registry edit для варианта. Sit/new objective types не обязательны;
- headless placed/spawned composition + physical scene capability contract PASS; subjective Inspector/visual ergonomics остаются в owner QA, без заявления об автоматическом visual pass;
- Smart Objects reservation flow PASS;
- Schedule/goal selection/LimboAI existing obligation flow PASS; GOAP deferred и не mandatory gate;
- ACTIVE↔DORMANT participation + per-field aggregate/actor authority + current-format save PASS; physical roots retained, body detach/новый travel/четыре tiers deferred;
- Content Doctor full scan PASS;
- unified game time/seed tests PASS;
- Gameplay Debugger owner QA подготовлена;
- parser/project structure/profiled GUT/headless smoke PASS.

## Review

Провести отдельный architecture review. Каждый finding получает FIXED / ACCEPTED_WITH_REASON / OUT_OF_SCOPE_WITH_TASK.

## Gate

Только после этого начинать Phase 3 Code Style.
