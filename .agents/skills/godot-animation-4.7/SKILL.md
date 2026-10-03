---
name: godot-animation-4.7
description: >
  Use for Godot 4.7 AnimationPlayer, AnimationTree, state machines, blend spaces,
  root motion, animation events, and Tween work in this project.
---

# Godot 4.7 Animation

Use this skill when animation runtime behavior is part of the task. Keep gameplay authority in project systems/components; animation is normally presentation or motion output, not a second gameplay state machine.

## Tool choice

- `AnimationPlayer`: authored clips and keyed properties.
- `AnimationTree`: runtime blending/state-machine/blend-space orchestration over clips from an `AnimationPlayer`.
- `Tween`: short procedural interpolation for UI/presentation/one-off transitions.
- Skeleton/retarget/import configuration stays with the existing asset pipeline unless the task explicitly changes it.

## Ownership rules

- When `AnimationTree.active` owns tracks, do not also drive the same tracks with `AnimationPlayer.play()`.
- Gameplay state should select animation; animation state should not silently become authoritative gameplay state.
- Method/call tracks should not mutate core GECS authority unless an explicit contract already uses them. Prefer typed gameplay events/requests for domain effects.
- Keep transition names and parameter paths centralized as `StringName` constants when reused from code; avoid scattered magic strings.
- Root motion must feed the existing movement/physics owner rather than directly bypassing body authority.

## AnimationTree

- Confirm the tree is active and points at the intended AnimationPlayer.
- For state-machine roots, get `AnimationNodeStateMachinePlayback` from the correct `parameters/.../playback` path and use `travel()`.
- Blend parameter paths are name-sensitive and string-based; verify them against the actual tree before assuming a typo-free path.
- Avoid writing identical state/parameter values every frame when a state transition/event can update them less often.

## Tween

- Godot 4 Tweens are created with `create_tween()`; they are one-shot objects.
- Create a new Tween for a new sequence instead of reusing a finished one.
- Bind lifetime intentionally when tweening nodes that may be freed.
- For gameplay timing/authority, prefer explicit gameplay timers/state over hiding important rules inside presentation tweens.

## Imported clips

When working with imported character clips:
- preserve clip naming/resource contracts unless migration is explicit;
- distinguish import-time clip trimming/looping from runtime playback logic;
- verify first/last useful keys when source animations contain long leading/trailing idle spans;
- do not duplicate animation data into scripts when the authored/imported clip is already the source of truth.

## Validation

- Validate GDScript with Godot parser/diagnostics.
- Use live MCP to inspect the exact AnimationTree/AnimationPlayer parameters when path/state names are uncertain.
- Do not launch rendered gameplay merely to prove syntax.
- Animation feel, transition quality, foot sliding, and visual timing remain manual QA unless the user explicitly asks for runtime visual validation.

Source inspiration: adapted selectively from `gamedev-skills/awesome-gamedev-agent-skills` Godot animation guidance (Apache-2.0); project rules override generic guidance.
