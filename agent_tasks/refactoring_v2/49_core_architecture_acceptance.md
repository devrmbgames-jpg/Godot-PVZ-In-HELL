# Refactoring v2.49 — core architecture acceptance

Status: **IN_PROGRESS**

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

## Preparatory evidence (2026-10-10)

Dependencies42/48 remain OWNER_QA_PENDING;49 remains PLANNED and Phase3 is gated.
Independent strict domain structure/dependency reruns PASS with empty baseline at
180e403f8f1be66595126db7395e163b506a4378. Strict architecture and full structure/Doctor PASS
(91 scenes,3 dialogues,zero errors/review gates). Provider/console GUT21/323 and district
queue smoke16000-frame PASS belong to48. Prepare representative core regressions while
waiting for owner editor/visual approval; do not interpret these as completed49 acceptance.

Tooling88/88 and persistence baseline PASS after evidenced Content Doctor CLI compatibility
repair5e686deb68c4dc838ecbf1ab4a5e8dce146d88f4 (owned/closed in46). Full structure/Doctor
CLI rerun PASS91/3,zero errors/review gates. Windows48 QA export/menu/level headless startup
PASS; native rendering/focus QA remains pending. Core representative GUT preparation PASS:11 suites,175 tests /1902 assertions,25.271s; no runtime or shutdown errors (tests/artifacts/refactoring_v2_49_core_preparation_gut.log). Native authoring/placed/identity preparation PASS:3 suites,33 tests /281 assertions,1.444s; no diagnostics (tests/artifacts/refactoring_v2_49_authoring_preparation_gut.log).

## Preparatory architecture review / Gate

Immutable baseline dc7e9490e59510fefa820793874ae117fbb07d01 to source
f3739a750b294f1ddaddb7f3c8e89dd10ec3a9a8: ARCHITECTURE PASS, STYLE PASS; no material
findings in bounded cross-owner review. Reviewer VALIDATION NOT_RUN (source only).
Compiler/registration, reservation retirement, capped System cadence, schedule receipts,
retained participation/save ownership and read-only tooling contracts remain coherent.

Owner explicitly accepted both current Inspector/Direct Traits and Gameplay Debugger on
2026-10-10. Phase 3 remains gated until current automatic acceptance and review finish.

## Current acceptance (2026-10-10)

- Baseline: `c8b84b801d674a293d4519e266e2f656883617dd`, `dev` with owner edits preserved.
- Strict architecture/domain structure/dependencies PASS, empty migration baseline.
- Structure/Content Doctor PASS: 92 scenes, three dialogues, zero errors/review gates.
- Current core GUT PASS: 16 suites, 220 tests /2373 assertions, 47.516s; stderr empty.
  Covers typed flows, reservations, schedule, participation/save, time/random, direct Traits,
  placed bootstrap, authoring preview, debugger/provider and console presentation.
  Logs: `.artifacts/godot_agent/core49.{stdout,stderr}.log`.
- Live MCP found New Trait synchronous Inspector navigation disposing its signal source.
  Deferred native navigation fixes New/Make Unique/local settings; live companion regression
  PASS nine assertions, Inspector restored and no authored-content changes. Fresh MCP and
  headless parser diagnostics clean. This repair belongs to the Direct Traits task.
- Mandatory CLI runner repaired/verified under [tooling integration](../godot_agent_tooling_integration.md).
- Next: current smoke, immutable repair review/triage, archive accepted 42/48 and close49.
