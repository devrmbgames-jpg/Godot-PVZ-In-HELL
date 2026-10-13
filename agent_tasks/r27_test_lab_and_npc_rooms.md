# R27.5 — полный тестовый зал и10 изолированных NPC-комнат

Status: **OWNER_QA**

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
Implementation/native verification and exact-SHA review complete; owner resumed2026-10-14.
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
ResourceSaver scene creation, explicitly reviewed compliant; see RV-001 below.
Code checkpoint `25f6de748304171b935dba4084f8de78088f9906`.
Review PASS: BASE `5c1028cf43b39f40f19aec47aa1442686a87944e` ->
TARGET `25f6de748304171b935dba4084f8de78088f9906`; no material findings.
Reviewer architecture/style PASS, validation NOT_RUN;240s, UTC2026-10-13T19:42:18-19:46:18.
PASS: production week native completion, all7days with unchanged >=6/8 survival,
`tests/artifacts/district-20261014-053843158.log`; wrapper FAIL only shutdown4ObjectDB/2Resource.
PASS: connected actual2shifts/2nights/Morning3 write and fresh-process restore:
`tests/artifacts/district_release-write-20261014-054256206.log` and
`tests/artifacts/district_release-restore-20261014-054446891.log`, native exits0/0.
Shutdown35RID/413-414ObjectDB/325Resource/VariantPools remains KNOWN_ENGINE_LIMITATION/DEFERRED;
logs preserved, no gameplay/script errors.
Windows QA test-level export/headless menu+level120frames PASS:
`.export/windows/20261013-194408Z-25f6de74-r27-isolated-npc-rooms`, `.export/TEST_LEVEL.cmd`.
Build records preserved user working-tree edits (dirty=true). Export process log contains a
LimboAI temporary DLL-copy error beside the live editor; actual exported startup/BT initialization
has no script/runtime errors. This log is preserved and is not called a clean export-process log.

### Review triage

RV-001/P2 — REJECTED: validator heuristic `author` generates scenes. On current code SHA
`25f6de748304171b935dba4084f8de78088f9906`, independent review confirms native editor guard,
saved fingerprint, closed destinations, no overwrite, temporary-Node disposal and plugin cleanup.
Gameplay loads committed editable .tscn; no runtime source generation. This is the explicit
scene-first editor-tooling exception. Raw heuristic FAIL remains recorded, not relabelled PASS.

### Owner QA / blockers

Owner gameplay/visual acceptance of the expanded lab and all ten rooms remains open:
[R27 checklist](../qa_tasks/r27_acceptance.md).

### Next

Complete owner QA. Automated R27 scope is complete; continue remaining R26 as requested.
Preserve all unrelated user edits. Required visual/gameplay acceptance remains open.
