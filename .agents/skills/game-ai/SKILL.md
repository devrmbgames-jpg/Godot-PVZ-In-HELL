---
name: game-ai
description: Use for NPC sensing, behavior selection, navigation intent or AI update cadence; not LimboAI APIs alone.
---

# Game AI

Keep AI split into **perception -> decision -> intent -> movement/action execution**.

The project already has GECS, LimboAI, navigation/physics owners, and domain services. This skill defines how those layers cooperate; it does not introduce another AI framework.

## Architecture boundary

- GECS Components/Relationships remain authoritative gameplay state.
- LimboAI may own decision flow/orchestration, not persistent domain truth.
- Existing services/solvers execute domain actions.
- Navigation/pathfinding produces a route/next target; it does not own NPC goals.
- Physics/movement code turns intent into motion; decision code does not write physical transforms directly.
- Prefer an explicit intent such as target/action/request over a BT task directly implementing combat, inventory, visit, or physics algorithms.

## Choosing the decision model

- Few mutually exclusive coarse states -> existing lifecycle/HSM/FSM may be enough.
- Reactive prioritized behavior with reusable branches -> LimboAI BehaviorTree.
- Continuous choice among comparable actions -> utility scoring can be used inside a narrow decision layer.
- Do not implement a custom behavior-tree runtime while LimboAI is installed.

For Utility AI:
- normalize considerations to a comparable 0..1 range;
- keep scoring functions pure where practical;
- add hysteresis/current-action bias when near-ties cause thrashing;
- keep utility scores advisory: the selected action still goes through the authoritative project service/request path.

## Runtime cadence

Decision work usually does not need render-frame frequency.

- Sense/update expensive world information only as often as gameplay requires.
- Repath on meaningful target movement, invalidation, or a bounded timer instead of every frame.
- Preserve multi-frame action state; a running action must not restart on every decision tick.
- Avoid allocations, broad ECS/world searches, resource loads, or full scene scans inside every AI tick.
- Cache stable references only when lifecycle/invalidations are clear.

## Behavior quality

NPC logic should explicitly handle:
- target invalidation/death/removal;
- unreachable navigation targets;
- stuck/timeout recovery;
- interruption by higher-priority state;
- clean exit/reset of abandoned long-running actions;
- deterministic ownership of who can cancel or replace an action.

Avoid oscillation by using thresholds/hysteresis rather than adjacent conditions that flip every tick.

## Debugging

Expose the smallest useful diagnostics:
- current high-level intent/state;
- active BT branch/task when LimboAI debugging is needed;
- current target/goal;
- navigation reachability/stuck state;
- utility scores only when tuning Utility AI.

Do not add permanent per-frame logging for AI state.

## Validation

Use the narrowest deterministic checks first. For behavioral quality that requires observation, request a small manual gameplay check rather than automatically launching a broad simulation.

When LimboAI API details are involved, also load `.agents/skills/limboai-v1.8/SKILL.md`.

Source inspiration: adapted selectively from `game-ai` and `ai-behavior-trees-utility-ai` in `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0); project architecture overrides generic guidance.
