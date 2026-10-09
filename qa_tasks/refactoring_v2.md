# Refactoring v2 — owner QA

Status: **OWNER_QA**

Implementation follows `agent_tasks/refactoring_v2/README.md`; this list owns subjective
acceptance that cannot be proved by detached/headless checks. No rendered QA is claimed.

## Entity authoring (42)

- Run `content/editor/entity_authoring/install_entity_authoring.gd` once in the script editor;
  select an NPC/Trader and an interactable. Check Simple/Advanced Inspector readability,
  separate instance/Template IDs, recipe/provider diagnostics and named binding editing.
- Place/duplicate the real scenes: mesh, collision and markers remain visible/editable.
  Assign/repair the new instance and nested slot IDs; Undo/Redo restores the previous values.
- Change an unsaved Template/Profile value, validate, and confirm the report reflects it
  without overwriting the authored asset. A duplicate ID/missing binding/conflicting provider
  must show an actionable failure before play.
- Follow `docs/entity_authoring.md` for two NPC/Trader/combat variants and a reused-assets
  level. Assess whether the documented manual editing locations are practical.

## NPC participation (45)

- Latest Windows QA launcher: `.export/LATEST.cmd`; build
  `20261009-214532Z-3fad54ae-npc-participation-final` (menu/level headless startup PASS).
- Check daytime arrival/departure and repeated sleep/reload in the actual level for animation,
  collision and conversation continuity. Headless mode, identity, state and routing acceptance
  passed; subjective presentation remains owner QA. The build preserves current user edits
  and records a dirty worktree in its manifest.

Later milestones add only their remaining subjective acceptance here.
