---
name: gdscript-style
description: >
  Required for creating or modifying project-owned GDScript. Defines the
  project's human-first readability, naming, typing, structure, comments,
  and formatter/linter conventions.
---

# GDScript Style

Project-owned GDScript is written **for humans first**. The code should be easy to scan, debug, review, and change months later without reconstructing the author's intent.

Formatter and linter rules provide mechanical consistency. They do not replace judgment about readability, architecture, naming, or intent.

## Core priority

When choosing between equally correct implementations, prefer the one that is easier for a human to understand.

Do not optimize for:
- the fewest lines;
- clever expressions;
- the fewest local variables;
- avoiding helper methods at all costs;
- satisfying a cosmetic lint rule by making an architectural name less clear.

Prefer explicit intent, linear control flow, descriptive names, typed intermediate values, and visible logical phases.

## Naming

Use names that communicate the value's role, not merely its type.

Prefer:
```gdscript
var collision_point: Vector3
var target_entity: Entity
var damage_receiver: C_DamageReceiver
```

Avoid vague names such as `data`, `obj`, `tmp`, `value`, or `result` when a more specific role is known.

The larger a symbol's scope or lifetime, the more descriptive its name should be.

### class_name role prefixes and suffixes

Project architecture may intentionally encode a class role in `class_name` with a prefix or suffix. This is allowed even when a generic formatter/linter naming rule objects to the spelling.

Examples:
```gdscript
class_name C_Combat
class_name S_Damaged
class_name R_OwnerTarget
```

Consistent role prefixes/suffixes are useful because they let a human recognize Components, Systems, Relationships, or other architectural roles immediately while reading code.

Do not rename a clear architectural class solely to silence a generic class-name lint warning. Prefer a narrow project-supported lint exception for the intentional convention. Never disable unrelated lint rules globally just to make a task pass.

For ordinary names that do not carry a deliberate architectural convention:
- classes/types: `PascalCase`;
- functions, variables, signals, parameters: `snake_case`;
- private behavior/glue/UI API: leading `_`;
- constants and enum values: `CONSTANT_CASE`.

Avoid names that shadow Godot/inherited properties, methods, or important surrounding symbols.

## Narrative code

A non-trivial function should read from top to bottom like a short description of what the system does.

Prefer visible stages such as:
1. gather required state;
2. reject invalid cases;
3. perform the calculation/query;
4. apply the gameplay/state change;
5. trigger secondary effects.

Keep one level of abstraction inside a block where practical. Do not tightly interleave data acquisition, physics queries, gameplay decisions, mutation, UI updates, and logging when those phases can be made distinct.

Use guard clauses to keep the main path shallow. Do not keep an `else` after an unconditional `return` unless it materially improves clarity.

## Logical blocks and comments

Separate distinct logical phases in non-trivial functions with one blank line.

A blank line is not enough when the purpose of the next block is not obvious. Add a short comment above a complex block that explains **what the block is trying to achieve or why it exists**.

Good candidates for an intent comment include:
- several raycasts or shape queries combined to obtain one collision/result;
- collision filtering or fallback queries;
- transform or coordinate-space conversion chains;
- ECS query composition or relationship traversal;
- indirect/dynamic node or resource lookup;
- non-obvious ordering constraints;
- compatibility workarounds;
- multi-step state reconciliation.

Prefer:
```gdscript
# Cast through the interaction proxy to recover the actual world collider behind it.
...
```

Avoid comments that merely restate syntax:
```gdscript
health -= damage # Reduce health.
```

Comments should explain intent, constraints, reasoning, or a non-obvious sequence. Straightforward code should remain straightforward without commentary noise.

## Cognitive load

If understanding a block requires keeping many intermediate concepts in working memory, reduce the cognitive load.

Prefer one or more of:
- introduce well-named intermediate variables;
- split the work into logical phases;
- extract a helper whose name explains the operation;
- add an intent comment above the complex sequence.

Do not compress a multi-stage operation into a long call chain merely because GDScript permits it.

Prefer:
```gdscript
var runtime_data: Dictionary = service.get_runtime_data(entity)
var target: Node3D = runtime_data.get("target") as Node3D

if target == null:
	return

var target_position: Vector3 = target.global_position
```

over a chain that performs lookup, casting, traversal, and use in one expression.

Do not reuse one local variable for different semantic roles during the same function.

## Functions and helpers

Do not impose an arbitrary maximum function length. Length is not the goal; comprehension is.

Extract a helper when:
- the operation has a meaningful name that explains intent better than its implementation;
- a block operates at a different abstraction level from its caller;
- the same non-trivial operation is repeated;
- extraction significantly reduces cognitive load.

Do not split simple linear code into tiny helpers that force the reader to jump around without gaining meaning.

Function names should describe intent or outcome, not implementation trivia.

## Conditions and gameplay rules

When a boolean expression represents a meaningful rule, prefer naming the rule instead of repeatedly embedding a dense condition.

For example:
```gdscript
var can_receive_damage: bool = is_alive and not is_invulnerable and faction != attacker_faction

if not can_receive_damage:
	return
```

Avoid clever ternaries or dense boolean expressions for important gameplay decisions when an explicit name or branch is easier to inspect and debug.

## Types as documentation

Project-owned GDScript remains statically typed.

Use concrete types whenever inference crosses:
- `Variant`;
- untyped or heterogeneous `Array`/`Dictionary`;
- `get()` or other dynamic lookup;
- broad `Object`/`Node` boundaries;
- physics query dictionaries;
- dynamically loaded resources/scenes;
- APIs where the concrete return type is not obvious.

Typed intermediate variables are encouraged when they make a multi-stage operation easier to understand or debug.

Prefer concrete member types over broad engine base types when the real contract is known.

Use typed containers when their element/value type is stable and known.

## Lifetime and nullability contracts

Treat validity as part of the API contract, not as a defensive check to repeat everywhere.

### Required synchronous values

Inside one ordinary synchronous gameplay call stack, mandatory Entity/Node arguments are expected to remain valid. Required Components/Relationships established by the caller/query are expected to exist.

Do not write defensive soup such as:

```gdscript
func apply_effect(actor: Entity, health: C_Health) -> void:
    if not is_instance_valid(actor):
        return
    if health == null:
        return
```

when both values are required by the function contract.

If such a value is unexpectedly invalid, that is an invariant/lifecycle bug upstream. Fix the owner, caller, query, or destruction path.

### Valid reasons to revalidate

Use `is_instance_valid()` when a reference intentionally crosses a time/lifetime boundary and therefore may outlive its source call stack, for example:

- `call_deferred()` or another queued/deferred call;
- a deferred/queued signal;
- a World event/request that is queued and processed later;
- `await`, Timer, delayed callback, or stored Callable;
- an Entity/Node reference cached in a member/container for later use;
- cleanup/teardown where object lifetime is explicitly uncertain.

Do not assume every signal or World event is asynchronous: if the concrete API dispatches synchronously, it does not become a lifetime boundary merely because it is called an event.

### Optional values

A `null` check is correct when absence is an intentional part of the API, such as an optional Component, optional target, lookup miss, or nullable authored reference.

Required and optional state must be distinguishable from the contract. Do not silently reinterpret a required value as optional just to avoid an error.

### Assertions

For suspicious required-state failures, prefer a debug assertion over a silent guard:

```gdscript
assert(is_instance_valid(actor), "Combat actor must be valid during a synchronous transaction.")
assert(health != null, "C_Health is required by this code path.")
```

Assertions document and expose invariants; they are not runtime recovery. Keep assertion expressions free of side effects and never rely on an assertion to perform work needed by release builds.

Do not replace legitimate boundary validation with `assert()`: deferred/queued/stored references still require real runtime handling when expiry is expected.

### Destruction invariant

Gameplay code must not intentionally invalidate mandatory Entity references in the middle of a synchronous gameplay transaction. Prefer the project/GECS lifecycle path, CommandBuffer, or queued deletion/removal so structural destruction happens at a controlled boundary.

## Public API and documentation

Each project-owned script has a short `##` description.

Document with concise `##` comments:
- every `@export` field;
- public variables that form a deliberate API/data contract;
- signals;
- public methods whose purpose is not self-evident.

Documentation should explain the contract, ownership, units, lifecycle, or important constraints rather than paraphrasing the symbol name.

Behavior/glue/UI members are private by default. All `@onready` members are private unless a deliberate external contract requires otherwise.

## Regions and file structure

Use named `#region ...` / `#endregion` blocks as chapters of a script, grouped by responsibility.

Good examples:
- `Lifecycle`;
- `Targeting`;
- `Physics Queries`;
- `Damage`;
- `Debug`.

Do not create a region around every function or tiny group. Regions should improve navigation, not add ceremony.

Keep closely related declarations and methods near each other when doing so does not conflict with a stronger project/API convention.

## Constants and literals

Avoid unexplained gameplay or tuning literals when the value carries meaning.

Use a named constant, exported value, resource/data field, or other authored source when the name would help explain the value's purpose.

Small universally obvious literals such as `0`, `1`, or simple loop bounds do not need ceremonial constants.

## Formatting and line length

The GDQuest GDScript formatter/linter and repository configuration are the mechanical formatting authority.

Treat 100 characters as the normal hard line-length target for project-owned GDScript. Prefer naturally readable wrapping rather than awkwardly shortening good names.

Do not manually fight formatter output unless it creates a real readability or correctness problem.

Do not change architectural names, collapse readable intermediate state, or otherwise make code harder to understand merely to remove a cosmetic lint warning. Use the narrowest intentional exception instead.

## Scope discipline

Apply this style to new and materially edited project-owned code.

Do not turn a focused task into a mass style rewrite of neighboring legacy code. Clean up nearby code only when it materially improves the changed behavior, removes ambiguity, or is necessary to make the edited area coherent.

When the user explicitly requested a broad refactor, this focused-task rule does not justify leaving the declared scope half-migrated. Load and follow `.agents/skills/refactoring/SKILL.md`: finish the chosen architecture migration, update all callers/contracts in scope, and remove temporary legacy paths before marking the milestone DONE.

Do not modify third-party/addon code for project style unless dependency/addon work is explicitly part of the task.

## Review question

Before considering a GDScript change complete, ask:

> Can another developer understand the purpose, control flow, important data types, and non-obvious operations by reading this code without reconstructing my thought process?

If not, improve the names, structure, intermediate values, helpers, or intent comments before relying on more documentation.
