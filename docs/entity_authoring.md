# Scene-first Entity authoring

Physical/visual composition belongs to editable native scenes. Templates/Traits supply
capabilities, Profiles/Definitions supply tuning, and the placed instance supplies identity
and named endpoints. The runtime and the Inspector preview use `EntityCompositionService`
and `EntityBuildRules`; preview never registers an Entity or starts a System.

## Assigning Traits in the standard Inspector

The persistent **Gameplay Traits** plugin is enabled in Project Settings → Plugins.
Its project-owned entry is `addons/project_entity_traits/plugin.cfg`, with implementation
under `content/editor/entity_authoring/`. It restores on restart; no installer script is needed.
Third-party GECS is unchanged.

1. Select the Entity root in the scene tree. Existing project actors inherit `E_TraitedEntity`.
   For a new raw GECS Entity, attach `content/shared/entities/e_traited_entity.gd`; retain its
   physical node type, mesh and collision. No per-object script is needed.
2. In **Gameplay Traits**, click **Add Trait** and select an existing EntityTrait `.tres`,
   for example `content/domains/combat/authoring/et_impact_capture.tres` for a physical actor.
   **New Trait** creates a local declarative resource; configure its ID and recipes.
3. Use **Make Unique & Edit** before tuning this instance. Shared Traits and Definitions
   should stay shared unless a deliberate local copy is requested. Native picker drag/drop
   assigns resources; arrows reorder and **Remove** deletes an entry.
4. Use **Validate Scene Composition**, inspect any nearby errors, then save the scene.
   All array changes use native Inspector Undo/Redo and serialize as scene/instance overrides.

If the plugin is disabled, the native exported `traits: Array[EntityTrait]` remains editable.
Expand that array, add an element and assign an EntityTrait resource using Godot's normal picker.
The plugin changes neither GECS identity nor runtime registration.

Direct `traits` is the only runtime source. `DEF_EntityTemplate` assets are optional editor-only
presets: copy their entries into `traits`; they are not referenced by production scenes.
The former `EntityAuthoring`, `metadata/entity_composition`, dock resource editor and one-shot
installer are removed. The retained **Entity Authoring** dock handles diagnostics and IDs only.

**Advanced Authoring** contains typed immutable `definitions`, named NodePath `bindings` relative
to the Entity, and `ancestor_entity_bindings` resolved to the nearest ancestor Entity. These use
the existing endpoint names and whole-set ownership validation; simple actors leave them empty.
**Advanced diagnostics** reports provider and per-field provenance, initial Relationships and
dependency/identity errors through the shared `EntityBuildRules` compiler. Scene/code and Trait
providers cannot silently override each other. Profile tuning retains its existing owner.

## Identity and validation

Select the level scene root to use **Create / Repair Level ID** for a new level scope.
This button is hidden for child objects, Entity prefab roots and an empty selection;
its handler only changes the selected level itself. Use **Create / Repair Instance ID**
for a newly placed/duplicated Entity. Both are explicit native Undo/Redo operations.
The dock listens to both the selected instance and level root: Repair, Undo/Redo and
selection changes update the displayed identity without rebuilding the base Inspector.
Renaming/reparenting a node does not change its stable token. Repairing an existing token
changes its save identity: reserve repair for a new instance or an intentional authoring change.
The generated identifier is a random valid token; whole-scene validation checks uniqueness.
Imported scenes and nested Entity children need unique local IDs too. Enable editable children
to configure a reused prefab's nested slots. Resource IDs and instance IDs are different inputs.

**Validate Scene Composition** captures the current scene and authored Resource values into
an ignored disposable snapshot. Script and physical-scene assets keep their external references;
the capture does not save over the original `.tscn` or `.tres`, including unsaved Trait edits.
The Inspector validates the detached copy synchronously through the shared compiler;
the dock runs the same preview in a separate headless process. No ready callback, ECS publication,
animation tick, AI execution, physics frame or gameplay effect runs on the preview actors.
The dock worker log is retained at `.artifacts/authoring_preview/last.log`; script failures are
reported as failures, not a clean authoring result. Native resource/scene dependency
cycles reject before loading the snapshot's graph.

A standalone factory prefab can report missing roster/Profile inputs: supply its owning district
in a level to validate placed construction, or use the existing factory's typed spawn context.
Preview does not fabricate a Profile, allocate a persistent NPC identity or repair requirements.
NPC roster preparation uses the same pure `NpcConstructionService.configure_placed` operation
as startup. Placed and spawned actors have the same runtime Component/Relationship contracts.

## Reused variants and levels

| Content change | Existing assets / owning input | Manual authoring locations |
| --- | --- | --- |
| Two district NPC variants | Copy `def_npc_profile_1.tres` / another existing Profile; set distinct keys and appearance/speed; add them to a copied district's `profiles` list. Keep `district_npc.tscn` and its direct Traits. | Two Profile assets and one district asset: 3. |
| Two Trader variants | Copy `def_trader_default.tres`, configure each catalog/tuning, and assign each to the scene's `C_Trader.profile`. Reuse `trader.tscn`; a district merchant uses the existing direct district Trader Traits and roster Profile. | Two Profile assets and two scene assignments: 4. |
| Two combat variants | Reuse `def_npc_punch.tres` / `def_npc_shot.tres`; configure a copied NPC Profile's `melee_attacks` / `ranged_attacks` or the generic scene-owned `C_NpcCombat`. Do not provide the same field from both. | One capability owner per variant: 2. |
| Two interactable variants | Inherit `box.tscn`, keep its mesh/collision/impact capability, and configure the existing actions or visual/tuning Resource in each inherited scene. | Two scene variants: 2, plus IDs for newly placed instances. |
| New gameplay level | Copy `primitive_test_level.tscn` and reuse its controller/World/mechanics; assign a new Level ID and a distinct save path when saves are enabled. Preserve the existing required node paths. Add variants as real scene instances. | Scene destination, Level ID and save path: 3, plus IDs for newly added/duplicated Entity children. |

For each workflow: create/copy → configure the owning Resources → place the real scene instance
→ assign new stable tokens where needed → validate the whole edited scene → save authored assets.
No runtime `.gd` generation or global registry entry is needed for these existing variant types.

`tests/fixtures/refactoring_v2/authoring_level.tscn` provides a minimal editable reuse example:
a physical NPC, Trader, box and nested inspection slot, four instance IDs in one level scope.
It is a detached authoring fixture, not a replacement for the authored gameplay level/World.
Subjective mesh/marker presentation and Inspector ergonomics require the owner's visual QA.

## Reproducible automated checks

```powershell
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://utils/preview_entity_authoring.gd -- res://content/scenes/main_level.tscn tests/artifacts/authoring_main.json
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_entity_authoring_preview.gd -gexit
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --script res://tests/fixtures/refactoring_v2/editor_authoring_check.gd
```

The editor check isolates unrelated plugins in memory and verifies persistent configuration,
Trait add/remove/assign/reorder, native Undo/Redo, local settings after scene save/reopen,
shared-resource protection and plugin fallback. It saves only an ignored scratch scene under
`.artifacts/direct_traits/`; project settings and authored source scenes are not saved.
The instantiated local-to-scene copy may have an empty path; the saved SceneState resource
has a built-in path. Both remain editable without another unique copy.
Preserve shutdown diagnostics: functional assertions do not prove an entire editor process
was diagnostic-free. Headless checks do not prove visual usability or gameplay feel.
