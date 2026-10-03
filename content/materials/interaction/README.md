# Interaction overlays

`MeshInstance3D.material_overlay` is reserved for interactive feedback and highlights throughout project-owned content. Other visual effects use their own geometry, base materials, material overrides or screen UI.

Edit the three native Godot `.res` materials here, or replace the exported `available_material`, `unavailable_material`, `busy_material` on `World/Systems/Interaction/S_InteractionHighlight` in shared `game_world.tscn`:

- `highlight_available.res`: amber, an actual contextual action is available.
- `highlight_unavailable.res`: red, e.g. overweight Carry-only furniture or a locked door without a usable key/action.
- `highlight_busy.res`: blue, another holder owns the item or an interaction captures the actor.

Modal UI hides the actor's target highlight. Eligibility is re-evaluated while aiming at the same target. Multiple viewers share one derived mesh result: available wins over busy, busy over unavailable. Last viewer cleanup restores the pre-existing interactive overlay, without changing base materials. If another interaction writer replaces an active highlight, this System yields until that target is released and does not erase the other writer's overlay.

Resources affect presentation only; action, health, access, weight and Relationships remain gameplay authority.
