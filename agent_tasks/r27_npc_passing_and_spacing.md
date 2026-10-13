# R27.2 — NPC обходят соседей и соблюдают личную дистанцию

Status: **IN_PROGRESS**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- Native physical NPCs pass each other through doors when free navigable space permits it.
- Nonaggressive NPCs keep at least1.5m from aggressive NPCs, stepping back/aside when needed.
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
REVIEW_PENDING: tested implementation checkpoint will be resolved to its full immutable SHA.

### Validation

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

### Owner QA / blockers

Owner gameplay acceptance of movement and threat behavior remains open.

### Next

Collect exact-SHA review; then continue the independent ten-room test lab milestone.
