---
name: limboai-v1.8
description: >
  Use only for LimboAI v1.8.1 behavior trees, BTPlayer/BehaviorTree resources,
  custom BT tasks, Blackboard, LimboHSM/LimboState, BTState, or version-sensitive
  LimboAI integration work.
---

# LimboAI v1.8.1

The project ships LimboAI as a prebuilt GDExtension under `addons/limboai/`; `addons/limboai/version.txt` is pinned to `v1.8.1`. Treat the addon as read-only unless addon upgrade/fix work is explicit.

## Context discipline

For GPT-6.1 Sol, keep LimboAI context narrow:

1. Start from the project behavior/resource/task being changed.
2. Use existing project contracts and owners before introducing new AI authority.
3. If LimboAI API behavior is uncertain, inspect only the exact class/symbol needed.
4. Use upstream `limbonaut/limboai` tag `v1.8.1` as the version-matched source/reference. Do not use `master`/latest behavior as authority for this checkout.
5. Do not preload the full LimboAI README, demo, class reference, or addon binaries.

## Project architecture boundary

LimboAI owns decision flow/orchestration, not authoritative gameplay state.

- GECS Components/Relationships remain authoritative project state and Entity-to-Entity bindings.
- Existing Systems, services/solvers, NavigationAgent, and physics bodies keep their current responsibilities.
- A BT task should normally observe project state, choose/request an action, or call a narrow existing API. Do not recreate movement, combat, physics, inventory, visit, or relationship authority inside the tree.
- Blackboard is per-agent/tree working context, parameters, cached references, and transient decisions. Do not turn it into a second persistent gameplay database or authoritative cross-Entity relationship store.
- If the same concept exists in GECS and LimboAI, define one authority and make the other an adapter/view of it.

## Behavior trees

Prefer built-in tasks and composition before writing custom GDScript tasks.

### General BT design principles

Use these framework-independent Behavior Tree practices unless an existing project contract requires otherwise:

- **Tree structure owns control flow.** Important decisions, ordering, fallback, priority, interruption, and repetition should be visible in the tree rather than hidden in leaf code.
- **Conditions observe; actions act.** Conditions should normally be side-effect-free and cheap. Actions should perform/request one concrete behavior.
- **Failure is normal control flow.** A leaf returning `FAILURE` often means “this option is not currently applicable”; selectors should be able to try the next strategy without treating that as an engine/gameplay error.
- **Keep leaves narrow and composable.** Prefer several named conditions/actions composed by the tree over one configurable “do everything” task.
- **Use subtrees for semantic behaviors.** Extract meaningful reusable branches such as combat, flee, service, patrol, or idle rather than copying them or hiding them in services.
- **Blackboard is context, not behavior.** Store parameters, targets, transient results, and cached references; do not encode a hidden FSM/BT through piles of mode flags and booleans.
- **Long-running actions need a lifecycle.** They must have explicit completion/failure conditions and release/cancel transient work when interrupted or exited.
- **Reactivity should be deliberate.** Use dynamic/reactive selectors or interruption mechanisms where higher-priority conditions truly need to preempt current work; do not re-evaluate expensive world queries every tick without need.
- **Prefer framework control nodes over hand-written control logic.** Sequence/selector/parallel/decorator semantics should come from LimboAI whenever possible.
- **Optimize only after the behavior is structurally correct.** Do not collapse a readable tree into a dispatcher action merely to reduce node count or script files.

Architecture self-check for every non-trivial tree:

> If all leaf implementation bodies were hidden and only task names/tree hierarchy remained, could a reviewer still understand the NPC's high-level decision logic?

If the answer is no, too much control flow is hidden in code and the behavior should be decomposed further.

### Tree structure is the decision model

The behavior tree resource must expose the important decision flow. Do not hide a second behavior tree, state machine, or branch selector inside one task or domain service.

- Use composites such as `BTSequence`, `BTSelector`, `BTDynamicSelector`, `BTParallel`, and their built-in variants to express ordering, fallback, priority, and concurrency.
- Use `BTCondition` leaves for observable gates such as "has target", "is threatened", "has service job", or "is allowed to idle".
- Use decorators for execution policy around one child: inversion, repeat, cooldown, timeout, probability, run limits, scope, and similar control concerns.
- Use `BTAction` only for leaf work: one narrow intent/effect that has no BT children and does not choose among unrelated behaviors.
- Use `BTSubtree` for reusable or independently understandable branches instead of growing one monolithic tree.
- Prefer built-in composites/decorators before creating custom `BTComposite` or `BTDecorator` classes.

A designer or reviewer opening the LimboAI tree should be able to understand the high-level behavior from the tree hierarchy without reading a large GDScript dispatcher.

### Do not simulate BT control flow inside an action

Treat these as architecture smells and split them into conditions/composites/decorators/subtrees:

- one `BTAction` containing a large `match` / `if-elif` chain that selects emergency, combat, service, schedule, idle, or other unrelated modes;
- an exported enum such as `branch_kind` / `owner_kind` whose main purpose is to make one action execute several conceptually different branches;
- a leaf action that calls a generic service such as `execute_branch(kind)`, `run_behavior(mode)`, or equivalent when that service itself performs the branch selection and sequencing;
- manually tracking child-like phases, retries, fallback, cooldown, timeout, or repetition inside an action when LimboAI already provides a composite/decorator for that control flow;
- using Blackboard flags as a hidden replacement for tree structure.

Domain services may still own substantial algorithms, but the BT should decide **when and which behavior** runs. Prefer narrow calls such as "request move to target", "begin attack", "accept service job", or "clear intent" over a service that executes an entire hidden behavior branch.

### Task responsibilities

- `BTCondition`: observational, cheap, and side-effect-free in normal use; return success/failure from project state. A failed condition is normally a decision result, not an exceptional error.
- `BTAction`: perform/request one leaf behavior; return `RUNNING` only while that behavior is genuinely in progress, then `SUCCESS` or `FAILURE`. If interruption can leave movement, targeting, animation, reservations, or other transient work active, clean it up through the task lifecycle/project owner.
- `BTDecorator`: modify execution/status policy of exactly one child; use it for control concerns such as inversion, cooldown, repeat, limits, timeout, probability, or scope rather than unrelated gameplay decisions.
- `BTComposite`: define child execution policy. Custom composites are exceptional; use built-in LimboAI composites unless the required control policy cannot be expressed cleanly with them.

### Authoring check

Before implementing or regenerating a non-trivial tree, sketch the intended hierarchy in compact form, for example:

```text
DynamicSelector
├─ Sequence Emergency
│  ├─ IsEmergency
│  └─ EmergencyAction/Subtree
├─ Sequence Combat
│  ├─ HasCombatTarget
│  └─ CombatSubtree
├─ Sequence Service
│  ├─ HasServiceJob
│  └─ ServiceSubtree
└─ IdleSubtree
```

Then implement that structure as native LimboAI tasks/resources rather than collapsing the branches back into one dispatcher action. Name tasks/subtrees by intent so the hierarchy reads like behavior, not implementation details.

Before accepting the authored tree, verify:

- priority/fallback order is visible from composites;
- branch eligibility is represented by explicit conditions or idiomatic LimboAI guards;
- long-running actions have clear success/failure/interruption behavior;
- repeated behaviors are subtrees/tasks rather than duplicated logic;
- Blackboard contains context, not a hidden mode machine;
- no leaf/service secretly selects among sibling behaviors that should exist in the tree.

- Execute reusable `BehaviorTree` resources through `BTPlayer`.
- Keep conditions observational; actions perform/request effects.
- Return `SUCCESS`, `FAILURE`, and `RUNNING` deliberately. A long-running action must have a clear completion/failure condition.
- Avoid expensive scene scans, broad ECS searches, allocations, or resource loads every tick. Resolve/cache stable inputs through the owning project layer or Blackboard when appropriate.

## Custom GDScript tasks

For v1.8.1 custom tasks, extend the narrowest base: `BTAction`, `BTCondition`, `BTDecorator`, or `BTComposite`.

- Use `@tool` when editor naming/warnings are useful.
- `_tick(delta: float) -> Status` is the essential callback.
- Use `_setup()` for one-time task initialization, `_enter()` for each activation, and `_exit()` for activation cleanup only when needed.
- Use `_generate_name()` and configuration warnings to make authored trees self-explanatory when that materially helps designers.
- Keep project GDScript statically typed. Cast/declare values read from Variant/Blackboard APIs explicitly when type inference is not guaranteed.
- Prefer exported `StringName` Blackboard variable names (typically ending in `_var`) over hard-coded magic strings.
- Validate object references from Blackboard with `is_instance_valid()` before use.
- Keep tasks small and reusable; move substantial project-domain algorithms into existing services/solvers rather than hiding them in a BT task.
- Moving code into a service does not make a monolithic BT valid: do not hide branch selection/sequencing behind a generic service call from one `BTAction`. The tree still owns decision flow.

## HSM

Use `LimboHSM` / `LimboState` for coarse mutually exclusive state lifecycles when an HSM is clearer than a BT. Use `BTState` when a state intentionally delegates its internal behavior to a tree.

Do not mirror the same lifecycle independently in GECS, an HSM, and a BT. Preserve the project's existing owner and add LimboAI as the decision adapter unless migration of authority is explicit.

## Validation

Use the cheapest falsifying check first: parse/static/resource checks, then a focused headless runtime check if lifecycle execution must be proven. Do not launch rendered gameplay or broad AI simulations automatically.

For subjective behavior, tree tuning, debugger inspection, or gameplay feel, ask the user for the smallest manual Godot check needed.
