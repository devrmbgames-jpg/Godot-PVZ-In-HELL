---
name: godot-4-7
description: >
  Implement and debug Godot Engine 4.7 code, scenes, physics, Resources, Node lifecycle,
  and 3D APIs. Use when editing .gd/.tscn/project.godot or choosing a version-sensitive Godot API.
---

# Godot 4.7

Target Godot **4.7** unless the project explicitly declares another version.

## Before editing

- Confirm `project.godot` version/features.
- Inspect the local scene/script contract before changing node ownership.
- For version-sensitive APIs, prefer Godot 4.7 documentation or the installed engine API.

## Visual-run boundary

Rendered Godot/editor runs, screenshots, screen capture, and agent-side visual inspection are forbidden by default.

They are allowed only after the user explicitly approves visual validation in the current task/conversation. Do not infer permission from UI/scene/graphics work or from approval in an earlier task.

Prefer, in order:
1. static/resource/scene inspection;
2. deterministic scripts;
3. headless Godot;
4. GUT/headless smoke;
5. concise runtime logs.

If only visual confirmation remains, report `NOT RUN — user visual validation required` and leave visual tuning to the user.

## Runtime rules

- Physics simulation and body mutations belong on the physics step.
- For controlled `RigidBody3D`, prefer forces/impulses and `_integrate_forces(state: PhysicsDirectBodyState3D)` when direct physics-state integration is needed.
- Do not overwrite RigidBody transform/velocity every render frame.
- Leave gravity, collision response, friction and bounce to the physics engine unless the mechanic explicitly requires custom integration.
- Use `_process` for presentation/render-rate work and physics callbacks for simulation.
- Distinguish local/global transforms and coordinate spaces.
- Use Node references as scene glue on Entity/Node classes. Keep reusable config/data in Resources/Components.

## GDScript 4.x

- Use `@export`, `@onready`, typed signals and `await`.
- Prefer `StringName` for stable action/property identifiers used repeatedly.
- Use `is_zero_approx()`, `clampf/minf/maxf` and typed math where appropriate.
- Multiply continuous rates by the proper step.
- Do not multiply accumulated mouse-relative input by `delta`.

## Scenes/resources

- Avoid editing imported/generated artifacts when source assets/scenes are authoritative.
- Do not invent Node paths: inspect the scene first.
- Do not commit machine-local absolute paths.

## Allowed integration pattern

```gdscript
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    S_Motion.integrate_forces(self, state)
```

Thin Entity callbacks are acceptable when they preserve Godot integration while keeping logic in Systems.
