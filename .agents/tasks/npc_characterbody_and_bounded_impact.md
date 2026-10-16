# НПЦ — CharacterBody3D и ограниченное отбрасывание

Status: **OWNER_QA**
Technical: **COMPLETE**
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

P1/P2 migration committed at `23e26a2541dab773a2a4db3cdc29e234c7ce657b` from foundation
`003af971102c4c6f40c4a478eeb9a35b63bd20f4`. RV-001 fixed and targeted cycle2 review collected PASS.
All live NPC/customer/trader prefabs now inherit the shared native CharacterBody foundation;
legacy rigid player/physical items keep their original bodies. Existing NPC scene UID, paths,
head/navigation/animation/parcel anchors and identity/visit contracts are retained.
Shared callback/look/contact ownership is documented in content/ARCHITECTURE.md and
docs/damage_impact.md. External response is separate from own speed (planar3/up1/decay10).
Native contacts remain mandatory for damage; raw proximity samples never replace native
reporters. Held bodies use real R_HeldBy and yielding springs, including raw test_move adapter.
Native heavy80kg/20mps response: peak2.833mps/displacement0.443m vs old10.977/7.716;
authored barrel18kg/20mps: peak2.833/displacement0.800, HP100->75 in both cases.
Current held-barrel press: max displacement0.0367m, zero knockback speed, grip retained;
anchor advances1.5mps for30 frames then holds through120. This differs from the old baseline
continuous-drive protocol, so those displacements are not a direct before/after comparison.
Walls/corner/ceiling, held support, raw hold/release, ordinary platform and real throw actor
receipt checks pass. Native step/slope, actual 60/120 Hz decay, navigation/avoidance and player
regression pass. Raw velocity fallback excludes authored native inbox reporters.
RV-001 repair moves bounded contact reconciliation into the motion solver immediately after
native slide. Native floor response retains planar velocity; one uniform projected cap adjusts
both body velocity and retained response. Recovery queries only report contacts. Native red/green
proves no converted own-motion residue with zero own intent/gravity/deceleration; mixed wall
pressure preserves gravity and recovers own8mps after release. Final native21/1016 also proves
solid narrow passage/end geometry and authored Walk/Idle chosen from actual velocity rather
than intent. Final source-matrix/test review collected PASS at
`d6f599dafc85af4d25f2b788a94aa75f5540a6ea`; no unresolved P0/P1/P2.
Windows QA artifact and headless menu/level are ready; rendered cases have not started (0/8).

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

Request task-specific approval for the six cases in the [.qa card](../../.qa/tasks/npc_characterbody_and_bounded_impact.md),
then execute only that finite authorized budget. Preserve identity/save/roles and prototype
tuning; no DONE until mandatory feel acceptance. Continue independent D2 while approval is pending.

## Validation / review

Baseline native6/17 and comparison JSON: `.artifacts/godot_agent/gut-20261016-182942880.*.log`.
Baseline/foundation reviews PASS/no findings; full evidence retained in the committed card
at `003af971102c4c6f40c4a478eeb9a35b63bd20f4`.
Migration review BASE `003af971102c4c6f40c4a478eeb9a35b63bd20f4`,
TARGET `23e26a2541dab773a2a4db3cdc29e234c7ce657b`: one P2, STYLE PASS, execution NOT_RUN.
RV-001 FIXED (`5a2cf2a66030b53d9faed4fc9d2fcf2e966316b2`, native19/741):
post-slide oblique projection could exceed planar/upward external caps.
Native red reproduced cache up1.416>1 and accumulating actual planar speed, log
`gut-20261016-200127909.*.log`. Final cycle2 handles every contact normal and retires inward
blocked planar axes in both native velocity and external state.
Native airborne multi-normal corner red `gut-20261016-201427846.*.log`; green
`gut-20261016-201854709.*.log` PASS19/741 CLEAN includes falling nonzero native velocity,
distinct normals in one result, cache/body decomposition and no launch after wall removal.
Cycle2 re-review BASE `b47c12ea029c56d13f0d2efd14bd2d0594575f18`,
TARGET `5a2cf2a66030b53d9faed4fc9d2fcf2e966316b2`: no material findings,
ARCHITECTURE/STYLE PASS, reviewer execution NOT_RUN. No unresolved accepted P0/P1/P2.
Source-matrix reconciliation remains open.
Native commands use `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/<suite>.gd`.
Logs below share prefix `.artifacts/godot_agent/gut-20261016-` and suffix `.*.log`.
All listed final runs are Functional PASS, stderr0 and CLEAN:

| Suite | Tests/assertions | Log timestamp |
| --- | --- | --- |
| npc_impact_motion (includes native animation/narrow passage) | 21/1016 | 202915778 |
| npc_gaze_freeze (nonimmune physical fixture; authored Angel immunity retained) | 16/122 | 192621089 |
| characterbody_physics | 8/41 | 194831926 |
| npc_activation | 12/119 | 191142241 |
| district_population (actual NPC/player footsteps) | 7/64 | 194829657 |
| npc_parcel_holder | 7/48 | 192152321 |
| s_grab | 92/438 | 203256810 |
| npc_remains | 7/76 | 192256831 |
| npc_participation_snapshot | 9/162 | 192254602 |
| customer_handoff | 14/125 | 192821106 |
| npc_test_rooms (all ten archetypes/day transitions) | 6/1452 | 193518200 |
| npc_traffic | 12/81 | 194100637 |
| npc_intent | 6/22 | 202724944 |
| contact_damage | 6/40 | 202727564 |
| combat_attribution | 4/18 | 202759184 |
| npc_attacks (native method-track callbacks) | 22/160 | 202801469 |

Final native smoke PASS: `tests/artifacts/npc_character-20261017-063126445.log` and
`tests/artifacts/npc_navigation-20261017-062928060.log`. Ancillary migrated smoke execution NOT_RUN.
Actual physics decay after 0.1s: external speed 1.999999642 at60Hz and 2.000000954 at120Hz.
Production/final test MCP checked/empty; formatter/lint, strict architecture, structure and
staged gates PASS. Native21/1016 precedes behavior-neutral capsule local-variable cleanup.
Inherited dialogue regressions exposed a fixture-only ambiguity: their World already contains
a legacy player, so execute_one could sample it instead of the new CharacterBody test actor.
Footstep test now establishes exactly one PlayerInput role before its native reader assertion;
production role ownership is unchanged. Inherited D1 run34/726 PASS/CLEAN (`202208405`).
Focused district_population rerun7/64 PASS/CLEAN (`202431799`) includes the final fixture
and duplicated-load cleanup. Scene migration remains reviewed; this is test isolation only.
Fixture checkpoint review BASE `5a2cf2a66030b53d9faed4fc9d2fcf2e966316b2`,
TARGET `41243ae7956505d6fceb008500e84403fc2b220a`: no findings, ARCHITECTURE/STYLE PASS,
reviewer execution NOT_RUN. Final source-coverage review BASE
`f7dd1812540e9bfbba0bfdb7d95341743b188b44`, TARGET
`d6f599dafc85af4d25f2b788a94aa75f5540a6ea`: no findings, ARCHITECTURE/STYLE PASS,
reviewer execution NOT_RUN. Detailed Source matrix is in the QA card; no criterion was waived.
Initial red runs and authoring failures retained in artifacts; not counted as acceptance.
Scene/Traits migration used native PackedScene/ResourceSaver with no-write preflight and editor
closed; incoming ShapeCast authored/saved with live MCP. Editor restarted through guarded launcher.
No schema change: same recipe/identity paths; active/dormant on-disk reconstruction passes.

### Windows QA handoff

Reviewed runtime SHA `d6f599dafc85af4d25f2b788a94aa75f5540a6ea`:
`.export/windows/20261016-204405Z-d6f599da-npc-characterbody-bounded-verified/PVZInHell.exe`.
`utils/export_windows.ps1` command PASS; exported menu/level120 frames each PASS, stderr0;
`.export/LATEST.cmd` updated. Dirty flag is the preserved pre-existing addons/gecs metadata.
First export's editor hot-reload DLL-copy error is absent after clean editor shutdown/re-export.
Exporter shutdown Resource/RID category follows owner DEFERRED policy; generic ObjectDB and
PagedAllocator remain UNKNOWN/mixed, not a diagnostic PASS. Raw export logs retained; no new
retention investigation or engine-policy expansion. QA may target the reviewed native MCP runtime;
exporter shutdown diagnostics are not evidence of a runtime Source-contract failure.

## Owner QA / blockers

Числа ограничений/затухания — обратимые Inspector-настройки прототипа, не утверждённый баланс.
Rendered QA требует отдельного разрешения. Технически готовый пакет может разблокировать
потребителя до субъективной приёмки, но незавершённая миграция не становится DONE.
