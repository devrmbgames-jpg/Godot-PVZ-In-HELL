# R27.2 — NPC обходят соседей и соблюдают личную дистанцию

Status: **IN_PROGRESS**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- Native physical NPCs pass each other through doors when free navigable space permits it.
- Nonaggressive NPCs keep at least1.5m from aggressive NPCs, stepping back/aside when needed.
- Emergency/combat/fleeing intent overrides ordinary social distance, waiting and threats;
  physical capsule/navmesh collision avoidance remains active.
- Two aggressive blockers threaten each other and accumulate pair-specific aggression while expecting yielding.
- A player-observed frozen angel is bypassed silently; no threat/escalation or phasing through it.
- An unobserved moving angel yields/bypasses other NPCs itself.
- Preserve navigation/Controller intent and body physics authority; no teleport-based passing.
- Focused native steering/collision/social/freeze regressions; actual visual feel remains owner QA.

### Current / owners

Base `2636f85dd143841f8586827ba3ee996056b9456a`.
S_NpcIntent owns native local steering, encounter clocks and deferred exact live bindings.
C_NpcTraffic owns transient side/cooldown; R_NpcBlocking owns the live encountered actor.
Typed authored DEF_NpcTraffic supplies1.5m spacing and anticipation/cadence tuning.
Native capsule sweeps/navmesh test both passing sides; physics remains body-owned.
Idle backstep initializes only the derived NavigationAgent path, preserving goal/generation.
Aggressive pairs wait, show mutual barks and append existing durable pair-specific THREAT memories;
subsequent social reactions derive bounded aggression from those memories, without a second cache.
Observed angels remain solid/silent; mobile angels supply their own detour/RVO yielding.
Participation/reset/death retire transient encounter state; queued operations revalidate live state.
Original review: `2636f85dd143841f8586827ba3ee996056b9456a` ->
`7e67e938e154c071203c5efcd27c8b539c66aa4b`, architecture FAIL for RV-001,
style PASS, reviewer validation NOT_RUN (2026-10-13,512s).
Independent exact-SHA review on 2026-10-15 confirms RV-001 fixed at
`5c1028cf43b39f40f19aec47aa1442686a87944e`, but finds RV-002/P1 below.
Targeted re-review of `5c1028cf43b39f40f19aec47aa1442686a87944e` ->
`ead2a026cb512f9a5e2a6445c10f6ca647ae6cfe`: architecture/style PASS,
no remaining material findings. One read-only reviewer; main alone writes/runs checks.
Native UID repair `82c5c617d793b6985b15256a8915332f50b14b4d` separately reviewed
architecture/style PASS; no change to movement code, scenes or component recipe.
CLI validation used local checkpoints `2312917393f484a502f9344315a244ea22923d4f`
and `4600a5f3142d0a12f7e7ba4202f02aa6197e8788`. Published code-fix tree
`6f0ed9bad102214d30495cfbec73c153f4c29900` equals the first local tree;
all three implementation/test files at the published UID checkpoint equal the second.
Independent reviewer verified this mapping; different publication SHA does not hide source changes.
Implementation/review complete for these findings; task remains IN_PROGRESS for Owner QA.

### Validation

#### Earlier milestone evidence (2026-10-13, not rerun)

PASS: native traffic10/59 (`gut-20261013-093048817`) plus head-on mobile-angel1/8
(`.artifacts/traffic-angel-head-on.log`); intent6/22 (`gut-20261013-093337516`),
social rules9/63 (`gut-20261013-093450356`), native gaze15/110 (`gut-20261013-093505738`).
Total41tests/262assertions; existing narrow corridor and stationary queue regressions included.
Initial traffic FAIL8/10 (`gut-20261013-092610867`): idle native avoidance stayed zero,
spacing reached1.4178m. Repaired by local path activation and anticipatory tangent steering;
current checks enforce full1.5m, no reduced acceptance.
PASS: parser10 (`parsefiles-20261013-093540279`), live MCP path diagnostics10 checked/error0,
formatter/structure, strict architecture, project structure and persistence inventory.
PASS: production7-day `district-20261013-193629385.log`, unchanged >=6/8 survival.
Connected write `district_release-write-20261013-193606194.log` native PASS;
fresh restore `district_release-restore-20261013-193921066.log` PASS/exit0/result JSON.
Write wrapper reports only known shutdown retention: KNOWN_ENGINE_LIMITATION/DEFERRED.

### Findings / disposition

RV-001/P1: S_NpcIntent::_urgent omitted native EMERGENCY/hazard distress and could stop
aggressive hazard escape for threats. Verified reviewed/current source and authored native BT.
FIXED at `5c1028cf43b39f40f19aec47aa1442686a87944e`: EMERGENCY/COMBAT ownership and sensed hazard distress exempt
both traffic waiting and deferred threat commit; no changed movement goal or body authority.
PASS: actual hazard/authored emergency BT encounter1/14 (`.artifacts/traffic-native-emergency.log`),
parser2 (`parsefiles-20261013-095159119`), MCP2/error0, focused formatter/lint and strict architecture.
Independent source re-review now PASS against the prior reviewed checkpoint above.

RV-002/P1: `_passing_direction` applied1.5m social retreat to a nonaggressive urgent NPC
before the mutual-threat guard. Native reproduction on the original source, with friendly
at x=-0.7, aggressive at x=0.7 and escape toward +X: preferred velocity.x=-0.963167.
All four isolated urgent sources (EMERGENCY, COMBAT, hazard_distress, fleeing) failed
the positive-progress assertion:1 parameterized test,24/28 assertions, exit1.
FIXED at `ead2a026cb512f9a5e2a6445c10f6ca647ae6cfe`: `keep_space` excludes urgent
current actors; ordinary capsule steering, side sweeps and RVO still run. Re-review PASS.

Independent [native NPC impact UID defect](completed/r27_native_npc_impact_uid.md):
restored the existing referenced UID; no authored recipe/path changes.

### Current focused validation (2026-10-15)

Godot4.7.1.stable.official.a13da4feb, GUT9.7.1, pinned GECS
`14d4282e5c1cb2713c187706ba2f5ff4e315d36e`; headless CLI, no visual checks.

- PASS traffic:14/14 tests,137 assertions,46.99s (`.artifacts/rv001-traffic-after.log`).
  Includes4 isolated urgent sources, queued normal->emergency threat rejection for either
  participant, actual hazard/native BT with both aggressive and friendly escape actors,
  full ordinary1.5m spacing, pair-specific aggression, angels, narrow corridor and queue.
- PASS intent:6/6,22 assertions (`.artifacts/rv001-intent.log`).
- PASS social/risk rules:9/9,63 assertions (`.artifacts/rv001-social-rules-final.log`).
  Initial8/9 was invalid-UID diagnostics; the separate resource repair resolves it.
- PASS final native hazard recheck after UID repair:1 parameterized test,28 assertions,
  both profiles, no warning (`.artifacts/rv001-native-final.log`); no full-suite repetition.
- PASS strict changed-script parser:2 files,0 failures,exit0
  (`.artifacts/rv001-parser-final.log`); no parser warning waiver.
- PASS GDQuest0.26.2 incremental formatter/lint, incremental architecture guard,
  strict architecture (0 lexical findings), task-scoped Git whitespace checks.
- FAIL general project structure: same26 findings as the initial unchanged5c1028 checkout
  (missing local export/evidence/temp artifacts and existing path references); no changed
  file flagged. This repository-wide gate is not claimed PASS or silently repaired here.
- NOT_RUN live Godot MCP (no connected tool); full suite, production-week/save smoke,
  GitHub Actions and visual QA were not rerun/requested for this scoped review.

Reproduce after normal headless editor import of a fresh checkout, using Godot4.7.1:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_npc_traffic.gd -gexit
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_npc_intent.gd -gexit
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_npc_rules.gd -gexit
godot --headless --path . --script res://utils/parse_gdscript.gd -- content/domains/npc/systems/s_npc_intent.gd tests/gut/test_npc_traffic.gd
```

### Owner QA / blockers

Owner gameplay acceptance of movement and threat behavior remains open.

### Next

Owner gameplay acceptance remains required; no automated Owner QA closure.
The ten-room test lab is an independent milestone and was not continued during this review.
