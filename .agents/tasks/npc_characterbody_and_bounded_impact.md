# НПЦ — CharacterBody3D и ограниченное отбрасывание

Status: **IN_PROGRESS**
Technical: **IN_PROGRESS**
Execution order: **50**
Reference baseline: `d6ea70fe8a00071ee9a5b57aa4a7e647e108ea27`
Source: [полное исходное ТЗ и доказательства](references/task-refactor-2026-10-17/npc_characterbody_and_bounded_impact.md.txt).

Эта карточка владеет текущим исполнением. Полный объём требований сохранён в Source;
правила чтения и автономного продолжения — в [README](README.md).


## Goal / acceptance

Перевести всех живых NPC в заявленной поверхности на общий CharacterBody-контур.
Ограничить суммарное внешнее отбрасывание, включая удерживаемые предметы и опоры,
не изменяя собственную скорость NPC, урон/авторство, навигацию, gaze-freeze и lifecycle.
Параллельный постоянный RigidBody-путь для части живых архетипов недопустим.
Полные контакты, миграционные гарантии и матрица Source обязательны.

## Current

P1/P2 implementation is in the working tree from reviewed foundation
`003af971102c4c6f40c4a478eeb9a35b63bd20f4`; not yet committed/reviewed.
All live NPC/customer/trader prefabs now inherit the shared native CharacterBody foundation;
legacy rigid player/physical items keep their original bodies. Existing NPC scene UID, paths,
head/navigation/animation/parcel anchors and identity/visit contracts are retained.
NPC look reuses CharacterLookSolver; physics reuses the same callback/slide/push/impact/support
composition as the authored player. Gaze/death/participation remain derived from their existing
owners; placement, reset and restore clear transient motion/contact samples.
Bounded external response is authored separately from own speed (prototype planar3/up1/decay10).
Native recovery contacts and a bounded authored ShapeCast retain incoming raw-body velocity;
proximity alone cannot create damage. S_Impact still owns pair deduplication/damage/attribution.
Held bodies use the actual R_HeldBy, including existing raw-body proxies; the spring yields at
bounded-character contacts. The generic adapter uses native test_move, never a borrowed body
state outside its callback. Contact reporting settings are unchanged by pickup/release.
Native heavy80kg/20mps response: peak2.833mps/displacement0.443m vs old10.977/7.716;
authored barrel18kg/20mps: peak2.833/displacement0.800, HP100->75 in both cases.
Current held-barrel press: max displacement0.0367m, zero knockback speed, grip retained;
anchor advances1.5mps for30 frames then holds through120. This differs from the old baseline
continuous-drive protocol, so those displacements are not a direct before/after comparison.
Walls/corner/ceiling, held support, raw hold/release, ordinary platform and real throw actor
receipt checks pass. Native step/slope, actual 60/120 Hz decay, navigation/avoidance and player
regression pass. Raw velocity fallback excludes authored native inbox reporters.
Implementation review and final source-matrix reconciliation remain open.

## Work packages

| Пакет | Проверяемый результат |
| --- | --- |
| P1 | Один NPC использует обобщённый существующий CharacterBody solver; player input/physics не скопированы и не сломаны. |
| P2 | Суммарный rebound/impulse ограничен; held-object, стены/потолок и platform velocity не обходят предел; damage attribution сохранена. |
| P3 | Все живые сцены, authoring traits, шаги/анимация, gaze-freeze, placement/death и restore переведены; старый живой путь удалён из scope. |

Каждый пакет включает соответствующие реальные headless проверки; P3 закрывает
общую миграционную матрицу. Не выдавать пилот P1 за завершение всей задачи.

## Entry points / dependency gates

Начать с e_npc_character.gd, e_district_npc.gd, npc_character.tscn,
kinematic_character_solver.gd, C_CharacterBody/C_Motion и KinematicImpactCapture.
Сохранить связи et_npc_identity/brain_state/roles, S_Impact и s_npc_footsteps.
Не ждать новой социальной системы: P1–P3 используют существующие damage/intent контракты.
P3 предоставляет body/eye/velocity bindings восприятию и Гремлину.

## Next

Commit the coherent migration and request one exact-SHA read-only review from BASE
`003af971102c4c6f40c4a478eeb9a35b63bd20f4`. Collect/triage accepted P0/P1/P2 before closing.
Reconcile remaining source-matrix coverage, then prepare the task QA card and Windows build;
rendered feel QA has
no task-specific approval yet (0/8). Do not claim P3/DONE or export QA PASS prematurely.

## Validation / review

Baseline native6/17 and comparison JSON: `.artifacts/godot_agent/gut-20261016-182942880.*.log`.
Baseline reviews PASS/no findings: BASE `97ff746acc84576a3be98dc8102565d31c391230` ->
`c407a2d82fc55dd331c5ea240c20328ee78dd918` -> `1f54cd6dba8355ade27c38a5271e1d5fb2029afa`.
Foundation review PASS/no findings: BASE `1f54cd6dba8355ade27c38a5271e1d5fb2029afa`,
TARGET `003af971102c4c6f40c4a478eeb9a35b63bd20f4`; reviewer execution NOT_RUN.
Accepted P0/P1/P2 findings: none. Current implementation review NOT_RUN.
Native commands use `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/<suite>.gd`.
Logs below share prefix `.artifacts/godot_agent/gut-20261016-` and suffix `.*.log`.
All listed final runs are Functional PASS, stderr0 and CLEAN:

| Suite | Tests/assertions | Log timestamp |
| --- | --- | --- |
| npc_impact_motion | 16/410 | 195331072 |
| npc_gaze_freeze (nonimmune physical fixture; authored Angel immunity retained) | 16/122 | 192621089 |
| characterbody_physics | 8/41 | 194831926 |
| npc_activation | 12/119 | 191142241 |
| district_population (actual NPC/player footsteps) | 7/64 | 194829657 |
| npc_parcel_holder | 7/48 | 192152321 |
| s_grab | 92/438 | 192153695 |
| npc_remains | 7/76 | 192256831 |
| npc_participation_snapshot | 9/162 | 192254602 |
| customer_handoff | 14/125 | 192821106 |
| npc_test_rooms (all ten archetypes/day transitions) | 6/1452 | 193518200 |
| npc_traffic | 12/81 | 194100637 |

Native smoke PASS: `tests/artifacts/npc_character-20261017-054534733.log` and
`tests/artifacts/npc_navigation-20261017-054536656.log`. Ancillary migrated smoke execution NOT_RUN.
Actual physics decay after 0.1s: external speed 1.999999642 at60Hz and 2.000000954 at120Hz.
Final production MCP scripts checked/empty; formatter/lint (67 files), architecture(strict),
structure and staged agent validator/diff-check PASS. The final test-only duplicated-load cleanup has native
MCP diagnostics checked/empty; previous GUT result precedes that behavior-neutral cleanup.
Initial red runs and authoring failures retained in artifacts; not counted as acceptance.
Scene/Traits migration used native PackedScene/ResourceSaver with no-write preflight and editor
closed; incoming ShapeCast authored/saved with live MCP. Editor restarted through guarded launcher.
No schema change: same recipe/identity paths; active/dormant on-disk reconstruction passes.

## Owner QA / blockers

Числа ограничений/затухания — обратимые Inspector-настройки прототипа, не утверждённый баланс.
Rendered QA требует отдельного разрешения. Технически готовый пакет может разблокировать
потребителя до субъективной приёмки, но незавершённая миграция не становится DONE.
