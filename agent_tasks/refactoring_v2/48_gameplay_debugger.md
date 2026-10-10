# Refactoring v2.48 — Gameplay Debugger

Status: **IN_PROGRESS**

Зависимости: [46_content_doctor.md](../completed/refactoring_v2/46_content_doctor.md), AI/Traits/LOD contracts готовы.

## Goal

Сделать архитектуру наблюдаемой без логирования всего мира.

## Selected Entity view

Показывать как минимум:
- Components;
- Relationships;
- current Goal;
- active obligation/action и selection/cancel reason; GOAP plan только при введённом optional planner;
- LimboAI status/reference;
- Intent;
- reservations;
- perception summary;
- Simulation LOD;
- recent gameplay events.

## Constraints

Debugger read-only по умолчанию.
Не создавать debug gameplay authority.
Использовать существующий LimboAI debugger, а не дублировать его tree inspector.

Read-only diagnostic snapshots/reason codes создаются в 40–45 вместе с владельцами состояния. Задача 48 добавляет selected-Entity view, а не впервые изобретает observability после AI/LOD migration.

## Acceptance

По выбранному NPC можно понять "почему он сейчас делает это" без поиска по нескольким Services и постоянного stdout.

## Validation

Debug data provider tests + owner editor QA.

## Current / Next

46 is archived after repaired immutable review. Read-only selected-Entity provider and
native editable view are implemented inside the existing console input/focus lifetime.
Exact entity handles include dormant registered bodies. Weak selections are revalidated
on explicit refresh, never rebound to replacement actors. No scheduled debug behavior.

Provider reuses NpcDecisionDiagnostics, GECS Relationships and the existing bounded
BoundaryTrace. Snapshot values contain no live Objects; recent selected incoming/outgoing
events are capped at24 and include Entity/NPC/package/current-visit identities. Native
LimboAI Brain status/node/instance references route detailed inspection to its own debugger.

Owner QA rejected oversized buttons/text and unreadable console overlap. Revised UI is
implemented and re-reviewed; OWNER_QA_PENDING. Controls use Unique Name; authored opaque background
and theme_developer_console.tres provide14px fonts, compact styles and local base scale1.
Adapter themes both text context menus and restores console presentation on teardown.
Native container sizing keeps debugger/output/input separate, including640x360 half-height.
The owner conducts rendered/editor recheck;42 also remains pending.

## Validation / Evidence

- Revised native layout/provider/lifecycle/dock controller GUT PASS:17 tests/154 assertions,
  7.142s.
  Includes640x360 half-height geometry, both context menus, opaque background and teardown.
  Log: tests/artifacts/refactoring_v2_42_48_ui_fix_gut.log. Fresh seven-script parser,
  formatter, strict architecture, structure and staged-agent checks PASS.
- Content Doctor PASS92 scenes/three dialogues/zero errors and review gates,13.07s.
  UI source226e127409cbb9af7dc8a4bda43e98055189851e; authoring review delta repair
  9920424403941c6e6b816ffa52739968a63a5a52 and final lifetime fix
  4fdf9867f50a3bee0718a783e17b26929602420e. Bounded re-review ARCHITECTURE/STYLE PASS;
  reviewer VALIDATION NOT_RUN. Fresh final delta parser two/zero PASS.
- Visual recheck NOT_RUN; headless layout does not prove subjective readability/focus.

- PASS: provider/native panel/existing console GUT,21 tests /323 assertions
  (`tests/artifacts/refactoring_v2_48_final_gut.log`). No errors before the PASS marker;
  process exit1 is shutdown-only Godot4.7.1 Resource/GDScript/RID retention, logs preserved,
  KNOWN_ENGINE_LIMITATION / DEFERRED. No retained live Nodes were reported.
- PASS: final changed-script parser, five files /zero failures
  (`tests/artifacts/refactoring_v2_48_final_parser.log`).
- PASS: integrated structure/Content Doctor,91 scenes /three dialogues, zero errors and
  zero review gates,12.32 seconds (`tests/artifacts/refactoring_v2_48_acceptance.log`).
- PASS: incremental formatter, agent-change and strict architecture checks.
- NOT_RUN: owner editor QA (readability, clipping, keyboard/mouse focus, native LimboAI
  integration). Prior source evidence below is distinct from revised UI evidence above.
  Concrete steps: `qa_tasks/refactoring_v2.md` and `docs/gameplay_debugger.md`.

## Review

Source180e403f8f1be66595126db7395e163b506a4378, baseline
f6ff19551bcb9927b392d3d1b4e38b31ef5120c3: ARCHITECTURE PASS, STYLE PASS; no material
findings. Reviewer VALIDATION NOT_RUN (immutable source only). Main tests above actually
ran; owner QA cannot be inferred from them.

PASS: authored district NPC queue smoke with16000-frame budget
(tests/artifacts/refactoring_v2_48_smoke.log); initial generic360-frame attempt ended before
the scenario completion marker and was not PASS. Strict domain structure/dependency rerun
PASS with empty baseline. Owner feedback requires UI recheck after the revision.

Windows QA export PASS: .export/windows/20261009-225258Z-180e403f-gameplay-debugger-review/
PVZInHell.exe, launcher .export/LATEST.cmd. Exported menu/level120-frame headless startup
PASS; manifest source180e403f,dev,Godot4.7.1,dirty user worktree preserved,player QA PENDING.
