# Scene-first Entity authoring

Physical/visual composition belongs to editable native scenes. Templates/Traits supply
capabilities, Profiles/Definitions supply tuning, and the placed instance supplies identity
and named endpoints. The runtime and the Inspector preview use `EntityCompositionService`
and `EntityBuildRules`; preview never registers an Entity or starts a System.

## Authoring dock installation

Open `content/editor/entity_authoring/install_entity_authoring.gd` in Godot's script editor
and use **File → Run** once per editor session. Running it again is harmless. Open the
separate **Entity Authoring** dock beside the Inspector. The EditorPlugin is project-owned
under `content/editor/`; it does not extend, hide fields in or otherwise alter the base
Inspector. Third-party addons and project plugin settings are unchanged. Closing the editor
removes the session installation. Restart the editor once when upgrading from the old
Inspector extension, then run the installer.

Edit the permanent layout in `content/editor/entity_authoring/entity_authoring_dock.tscn`.
Its controller binds controls by Unique Name. The dock's own native resource Inspector
edits Template/Profile/binding inputs; resource navigation stays inside this dock.

Select an Entity in the scene tree. The dock shows the instance and Template IDs separately,
provides explicit ID commands and opens the single scene-owned `EntityAuthoring` Resource.
Its `entity_template`, `definitions` and `bindings` remain the actual editable inputs.
Use a scene-contained Template for a one-off object or an external `.tres` for a reused variant.
Make a Resource unique before editing one instance's shared capability configuration.

**Advanced** exposes scene Component recipes and the compiler's resolved providers, per-field
provenance, initial Relationships and actionable conflict/requirement diagnostics. Scene/code
providers and Template providers cannot silently override each other; choose one owner.
Definition tuning belongs to its existing Profile, rather than copies in every Trait.

Bindings are named `NodePath` inputs relative to the Entity. Use the exact endpoint name
declared by the Trait (including a Home/Workplace name when the capability requires it).
The referenced node must resolve to an Entity in the accepted set. Adding a named endpoint
does not itself add a new gameplay behavior. Parent-owned slots use the existing
`ancestor_entity_bindings` contract, without a second editable endpoint provider.

## Identity and validation

Use **Create / Repair Level ID** for a new level scope, and **Create / Repair Instance ID**
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
the capture does not save over the original `.tscn` or `.tres`, including unsaved Template edits.
A separate headless process validates that detached copy. No ready callback, ECS publication,
animation tick, AI execution, physics frame or gameplay effect runs on the preview actors.
The worker log is retained at `.artifacts/authoring_preview/last.log`; script failures are
reported as failures, not a clean authoring result. Native Scene→Template→Scene dependency
cycles reject before loading the snapshot's graph.

A standalone factory prefab can report missing roster/Profile inputs: supply its owning district
in a level to validate placed construction, or use the existing factory's typed spawn context.
Preview does not fabricate a Profile, allocate a persistent NPC identity or repair requirements.
NPC roster preparation uses the same pure `NpcConstructionService.configure_placed` operation
as startup. Placed and spawned actors have the same runtime Component/Relationship contracts.

## Reused variants and levels

| Content change | Existing assets / owning input | Manual authoring locations |
| --- | --- | --- |
| Two district NPC variants | Copy `def_npc_profile_1.tres` / another existing Profile; set distinct keys and appearance/speed; add them to a copied district's `profiles` list. Keep `district_npc.tscn` and its Template. | Two Profile assets and one district asset: 3. |
| Two Trader variants | Copy `def_trader_default.tres`, configure each catalog/tuning, and assign each to the scene's `C_Trader.profile`. Reuse `trader.tscn`; a district merchant uses the existing district Trader Template and roster Profile. | Two Profile assets and two scene assignments: 4. |
| Two combat variants | Reuse `def_npc_punch.tres` / `def_npc_shot.tres`; configure a copied NPC Profile's `melee_attacks` / `ranged_attacks` or the generic scene-owned `C_NpcCombat`. Do not provide the same field from both. | One capability owner per variant: 2. |
| Two interactable variants | Inherit `box.tscn`, keep its mesh/collision/impact capability, and configure the existing actions or visual/tuning Resource in each inherited scene. | Two scene variants: 2, plus IDs for newly placed instances. |
| New gameplay level | Copy `primitive_test_level.tscn` and reuse its controller/World/mechanics; assign a new Level ID and a distinct save path when saves are enabled. Preserve the existing required node paths. Add variants as real scene instances. | Scene destination, Level ID and save path: 3, plus IDs for newly added/duplicated Entity children. |

For each workflow: create/copy → configure the owning Resources → place the real scene instance
→ assign new stable tokens where needed → validate the whole edited scene → save authored assets.
No runtime `.gd` generation or global registry entry is needed for these existing variant types.

`tests/fixtures/refactoring_v2/authoring_level.tscn` provides a minimal editable reuse example:
a physical NPC, Trader, box and nested inspection slot, four instance IDs in one level scope.
It is a detached authoring fixture, not a replacement for the authored gameplay level/World.
Subjective mesh/marker presentation and dock ergonomics require the owner's visual QA.

## Reproducible automated checks

```powershell
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://utils/preview_entity_authoring.gd -- res://content/scenes/main_level.tscn tests/artifacts/authoring_main.json
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_entity_authoring_preview.gd -gexit
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --script res://tests/fixtures/refactoring_v2/editor_authoring_check.gd
```

The editor check isolates unrelated plugins in memory and verifies native installation/ID undo.
`-- --baseline` runs the identical editor lifecycle without installation. Neither command saves
project settings. Preserve and compare shutdown diagnostics; the marker alone is not proof
that an entire editor process was diagnostic-free. Headless checks prove no visual/gameplay feel.
