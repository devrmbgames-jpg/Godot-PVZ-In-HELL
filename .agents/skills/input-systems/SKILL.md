---
name: input-systems
description: >
  Use for player input architecture, InputMap actions, edge/held semantics,
  mouse/gamepad look, rebinding, deadzones, buffering, and interaction-control
  priority in this project.
---

# Input Systems

The existing input pipeline is authoritative:

`Input/InputMap -> S_PlayerInput -> C_Controller -> S_PlayerIntent -> gameplay systems`.

Do not bypass it for ordinary gameplay features.

## Project routing

- `S_PlayerInput` captures raw engine input into `C_Controller`.
- `S_PlayerIntent` converts controller state into gameplay-space movement/look.
- `InteractionControlFocus` owns control priority.
- `InteractionActionResolver` owns contextual interaction actions.

Ordinary gameplay code must not add parallel raw E/F/LMB/RMB or mouse-look consumers when the same intent belongs in this pipeline.

Modal UI or a deliberately isolated editor/minigame input surface may capture input through its documented boundary; it must release capture cleanly.

## Input semantics

- Named actions are the stable contract; physical keys/buttons are bindings.
- Use edge/just-pressed semantics for discrete actions.
- Use held/axis semantics for continuous movement/aim.
- Consume one-shot actions once at the correct owner; avoid multiple systems independently interpreting the same raw press.
- Mouse motion is already a delta; do not multiply raw mouse look by frame `delta`.
- Apply sensitivity/curves/deadzones deliberately for analog devices.
- Prefer radial deadzones for 2D stick vectors unless per-axis behavior is intentional.

## Control focus

When a higher-priority mode owns controls:
- lower-priority movement/interaction must not leak through;
- look/move suppression belongs at the established focus/intent boundary;
- switching mode must not leave stale held/pressed state that fires immediately on release.

Preserve the documented MODAL / transport / push / carry / hands ordering and drawing capture rules unless the task explicitly changes the contract.

## Rebinding and accessibility

If rebinding is implemented:
- change bindings, not gameplay code;
- detect conflicts and allow reset-to-default;
- persist bindings through the settings/persistence layer;
- keep keyboard/mouse and gamepad navigation viable;
- expose sensitivity/invert/toggle-vs-hold where appropriate.

Input buffering/coyote-time should live close to the mechanic that consumes them, not as a universal hidden buffer for every action.

## Validation

For input changes, test the smallest relevant controller/intent/action surface first. Existing grab/interaction GUT coverage is preferred where applicable. Subjective sensitivity/feel still needs user gameplay QA.

Source inspiration: adapted selectively from `input-systems` in `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0); current input/focus architecture is authoritative.
