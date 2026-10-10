# Refactoring v2 — owner QA

Status: **OWNER_QA**

Implementation follows `agent_tasks/refactoring_v2/README.md`; this list owns subjective
acceptance that cannot be proved by detached/headless checks. No rendered QA is claimed.

## Entity authoring (42)

- Run `content/editor/entity_authoring/install_entity_authoring.gd` once in the script editor;
  select an NPC/Trader and an interactable. Open the separate Entity Authoring dock;
  the base Inspector must remain unchanged. Check the authored dock's readability,
  separate instance/Template IDs, recipe/provider diagnostics and named binding editing.
- Place/duplicate the real scenes: mesh, collision and markers remain visible/editable.
  Assign/repair the new instance and nested slot IDs; Undo/Redo restores the previous values.
- Select the level scene root and repair Level ID: the dock's Level ID updates immediately.
  Selecting an Entity or clearing selection hides the Level ID repair button; child objects
  cannot change their parent level's ID. Undo/Redo and switching between Entities keep the
  read-only displayed value current.
- Change an unsaved Template/Profile value, validate, and confirm the report reflects it
  without overwriting the authored asset. A duplicate ID/missing binding/conflicting provider
  must show an actionable failure before play.
- Follow `docs/entity_authoring.md` for two NPC/Trader/combat variants and a reused-assets
  level. Assess whether the documented manual editing locations are practical.

## NPC participation (45)

- Latest Windows QA launcher: `.export/LATEST.cmd`; build
  `20261009-225258Z-180e403f-gameplay-debugger-review` (menu/level headless startup PASS).
- Check daytime arrival/departure and repeated sleep/reload in the actual level for animation,
  collision and conversation continuity. Headless mode, identity, state and routing acceptance
  passed; subjective presentation remains owner QA. The build preserves current user edits
  and records a dirty worktree in its manifest.

## Gameplay Debugger (48)

- Windows QA build: `.export/LATEST.cmd` -> `20261009-225258Z-180e403f-gameplay-debugger-review`; exported menu/level headless120-frame startup PASS, rendered QA PENDING.

- In the actual editor-run level, open the developer console; use `debug_targets`, then
  `debug_inspect target` or `debug_inspect entity:<id>`. Check the two-column Tree, long
  node/asset paths, readable scale, scrolling and keyboard focus at the owner's resolutions.
- Check compact 14px text/buttons, an opaque dark debugger background, and small right-click
  context menus on both console output and command input. Output/input must not overlap.
- Select one live and one dormant NPC. Compare obligation, selection/cancel reasons,
  Intent, perception and physical/cadence participation with their authoritative Components
  and roster. Use Refresh after a meaningful gameplay transition; no automatic logging runs.
- Check a Smart Object reservation on its owner and object; owner/slot/token agree with the
  live Relationship. Recent events must concern the selected Entity/domain identities.
- Follow the displayed Brain node/instance in the native LimboAI debugger. Its tree inspector
  remains the detailed tree UI. Removing the selected actor must show UNAVAILABLE on Refresh.
- Close panel and console using buttons/normal keyboard paths; command input and mouse/focus
  restore correctly. Reopen without stale state. See `docs/gameplay_debugger.md`.

Owner feedback2026-10-10: instance repair/validation worked; Level ID display failed.
Inspector extension placement and console debugger readability were rejected. The revised
separate scene-authored dock and compact console layout require owner recheck. Owner handles
rendered/editor acceptance; headless checks do not close it.
