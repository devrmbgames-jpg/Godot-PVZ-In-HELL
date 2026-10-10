# Direct Entity Traits — owner Inspector and gameplay QA

Status: **OWNER_QA_PENDING**. Automated checks are recorded in
[the owning task](../agent_tasks/refactoring_v2/codex_direct_traits_inspector_tz.md).
No rendered gameplay or visual QA has been run by the agent.

1. Restart Godot and confirm **Gameplay Traits** is enabled in Project Settings → Plugins.
   Select the physical Box in `tests/fixtures/refactoring_v2/authoring_level.tscn`.
   Check the section is visible in the standard Inspector and controls fit your dock width.
2. On a newly created physical Entity, attach `content/shared/entities/e_traited_entity.gd`.
   Add `content/domains/combat/authoring/et_impact_capture.tres`, validate and save.
   Reopen the scene. No Template, authoring metadata or per-object script should be required.
3. Add with the resource picker and drag/drop; remove and reorder entries; undo and redo.
   Use **Make Unique & Edit** for one instance and check another instance keeps its settings.
   Save/reopen the local Trait and open its settings again without making another copy.
   Confirm duplicate/dependency/root/node/binding errors are understandable beside the list.
4. Try an inherited Box scene and editable nested physical slot. Save/reopen overrides;
   verify **Advanced Authoring** bindings and **Advanced diagnostics** are understandable.
5. Use the Entity Authoring dock to create/repair IDs for a new level and duplicated actors.
   Check Undo/Redo and whole-scene uniqueness errors. Existing stable IDs must stay unchanged.
6. Disable the plugin, edit the native `traits` array, then enable it and restart again.
   The export and authored values should remain available throughout.
7. Owner gameplay pass: main level, physical player/NPC, box/slots, package/hazard and customer.
   Confirm the established movement, impact, interactions and spawn behavior feel unchanged;
   save and load a new schema-10 session. Old-save conversion is intentionally excluded.

Record the owner result here and in the owning task. Task №42 retains its own owner acceptance.
