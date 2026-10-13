# R27.5 — полный тестовый зал и10 изолированных NPC-комнат

Status: **IN_PROGRESS**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- Existing primitive_test_level exposes all new R26 items with native physical scenes/capabilities.
- Testing access covers existing gameplay objects/mechanics, including parcel/terminal/truck/trade/day/save.
- Ten isolated authored locations are reachable from the test room and have a return transition.
- Each location contains only one NPC of its specific canonical archetype and receives two parcels/day.
- Explicit owner answer: **reset on every entry**; room does not restore prior progress.
- Native scene change releases old World/systems/roles/UI/signs and initializes the next scene exactly once.
- Repeated entry/return does not leak live Nodes, duplicate entities, stale bindings or inventory/slot references.
- Deterministic headless transitions/day-cycles and catalog/scene checks; Windows test-level export near closure.
- Do not overwrite gameplay saves; use isolated test-room save/session contract.

### Current

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`;
authored `content/scenes/primitive_test_level.tscn` and R26 catalog own the starting surface.
Live MCP editor connected; author scenes/resources through native editor operations.
No runtime gameplay .gd/.tscn generation. Native editor-only companion authoring created
ten rooms/presets/portal prefabs; standard MCP placed16 catalog items and10 hall portals.
Native MCP authored controlled light zones and installed the required district roster Trait.
Source hall was saved after native undo authoring of16 mandatory stable item IDs.
Owner resumed2026-10-14. Implementation is ready for milestone gates and immutable review.
Rooms use fresh native sessions without gameplay save slots or per-room progress caches.
Editor-only preset snapshots preserve original archetype rules; typed inline room tuning remains editable.
Companion guards reject gameplay, stale fingerprints, unsaved source and existing destinations.

### Validation

PASS: real native transitions/reset/cleanup496 checks,10 rooms/20 entries:
`.artifacts/npc-room-transitions-20261014-052713065.log`, process exit0.
PASS: bootstrap plus three physical daily supplies, single recipient and two registered cases/day:
GUT2/600, `.artifacts/godot_agent/gut-20261013-193043024.stdout.log`.
PASS: existing game-slot/session regression GUT6/43, `gut-20261013-193503385`.
PASS: MCP native bounded diagnostics; identity authoring is an unchanged no-op with all16 IDs;
room authoring refuses existing destinations. Native editor ownership remains clean.
PASS: changed-file formatter/lint, strict architecture, project structure and persistence baseline.
Historical transition FAIL (missing IDs/null scene) is repaired; current probe aborts on bootstrap
failure, bounds arrival and reports only actually completed rooms/entries.
PASS: companion guard/identity/preset/packing GUT6/240 (`gut-20261013-193714165`);
final native parser9 (`parsefiles-20261013-193822836`). Relevant final R27 GUT suite PASS.
Incremental staged architecture gate FAIL: one REVIEW heuristic for editor-only native
ResourceSaver scene creation. No runtime generation; exact-SHA review must triage it explicitly.
Production week, Windows export and immutable-SHA review still pending.

### Owner QA / blockers

Owner gameplay/visual acceptance of the expanded lab and all ten rooms remains open.

### Next

Collect final gates, commit/review exact SHA and export Windows test-level QA;
preserve all unrelated user edits. Required visual/gameplay acceptance remains owner QA.
