---
name: game-ui-ux
description: >
  Use for runtime HUD/menu/dialogue UI implementation, responsive Control layout,
  focus navigation, modal screens, UI-to-gameplay boundaries, localization-ready
  layout, and accessibility behavior.
---

# Game UI / UX

UI presents and requests; it does not become authoritative gameplay state.

## Layout

- Author stable screens, modal hierarchies and HUD layout as native `.tscn` scenes, editable in Godot Scene dock. GDScript binds state, signals and dynamic list rows; it should not build the whole permanent layout in `_ready()`.
- Existing script-built `content/ui/settings_menu.gd` is legacy debt, not a template to copy. Its dynamically generated input-binding rows remain a legitimate exception.
- Shared visual configuration belongs to `Theme`/`.tres` where Inspector editing helps designers. See `godot-scene-authoring` for scene ownership and exceptions.


- Prefer Godot Control anchors/containers/theme layout over fixed absolute pixel placement.
- Define an aspect/stretch policy rather than assuming one monitor size.
- Keep important UI inside safe margins when platform/display constraints require it.
- Let containers size around localized content; avoid layouts that only fit current-language strings.
- Use theme/resources for reusable styling instead of per-node copied constants when practical.

## Input and focus

Every modal/menu screen that supports keyboard/gamepad should:
- establish a sensible initial focus;
- have navigable focus neighbors/order;
- preserve mouse use;
- handle Back/Cancel consistently;
- acquire/release the project's modal control focus cleanly.

Do not create a second raw-input path inside ordinary HUD widgets.

## Gameplay boundary

- HUD reads derived/authoritative state and reacts to events/signals or bounded refreshes.
- UI must not directly mutate HP, inventory, package/customer state, GECS relationships, or physics state.
- User actions call the owning service/request/API.
- Avoid per-frame polling when the state already has a meaningful change event or explicit refresh lifecycle.

## Screen lifecycle

Make screen ownership explicit:
- open/show;
- input/focus acquisition;
- refresh from authoritative state;
- close/hide;
- focus/control release;
- cleanup/disconnect when the lifetime requires it.

Modal overlays should compose predictably rather than accumulating independent boolean flags that each partially disable gameplay.

## Accessibility

When relevant:
- scalable/readable text;
- visible controller/keyboard focus;
- reduced motion/flashing for strong effects;
- remappable controls through the input/settings layer;
- information not conveyed by color alone.

## Validation

Check the specific resolution/aspect/input path affected by the change. Parser/static validation cannot prove focus order, clipping, readable scale, or modal behavior; those need focused manual UI QA when materially changed.

Source inspiration: adapted selectively from `game-ui-ux` in `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0); project GECS/input/modal contracts override generic examples.
