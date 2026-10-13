# R27.2 — NPC обходят соседей и соблюдают личную дистанцию

Status: **PLANNED**

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

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`;
S_NpcIntent owns local passing/native avoidance, C_NpcGazeFreeze.observed owns freeze fact,
NpcSocialService owns remembered social reactions. Inspect nearest aggression/profile/motion contracts.
Implementation/testing/review NOT_RUN.

### Validation

NOT_RUN for this milestone; earlier visit tests do not verify physical passing or social spacing.

### Owner QA / blockers

Owner gameplay acceptance of movement and threat behavior remains open.

### Next

After R27.1, reproduce head-on doorway steering and implement typed spacing/yield/escalation inputs.
