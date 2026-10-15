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

Owner day-cycle finding2026-10-15 is reproduced and repaired; implementation checks and export PASS.
Real sleep remained in NIGHT with ERR_INVALID_DATA: a room has an empty save path but the
night owner still required a restorable persistence snapshot and disk write. No-save sessions
now finish evening obligations, reset actions, prepare the district and drain commands before
allowing MORNING, without snapshot/I/O. A separate transient preparation stamp does not claim
a successful file save and is invalidated by restore. Empty storage destinations are rejected.
Earlier supply tests incremented day_index directly; the new authored-station regression runs
two real day/sleep cycles in every room, without assigning calendar fields or bypassing gates.
Base for the day-cycle fix: `e298932551f16333868ee2208cb14f5b9545b4d7`.
Code/review target: `592774eacbe1301c157f12ad2172f34cb91cc508`.
Independent immutable review: no material findings; ARCHITECTURE/STYLE PASS,
reviewer VALIDATION NOT_RUN. Review duration/efficiency NOT_MEASURED.
Windows test-level export and headless menu/level startup120frames PASS:
`.export/windows/20261015-051409Z-592774ea-r27-room-night-cycle`,
launcher `.export/TEST_LEVEL.cmd`; dirty=true preserves unrelated owner edits.
Actual startup logs are clean. Export-only shutdown retention warnings remain
KNOWN_ENGINE_LIMITATION/DEFERRED; no clean export-process log is claimed.

Owner follow-up 2026-10-15 is implemented below; required manual acceptance remains open:
- NPC is absent in the isolated test locations; reproduce and fix native spawning/participation.
- Move each room's truck away from the exit, allowing for its full cargo footprint.
- Move the hall truck clear of the displayed items, to the side and reasonably near the terminal.
- Place the physical test items on authored pedestals using the existing knife display as reference.
- Add minimal testable animations for the scythe, axe and throwing knife.
Work is explicitly requested; scene changes use the live editor and preserve unrelated edits.
Previous PASS below describes the earlier checkpoint, not acceptance of these new findings.

Follow-up implementation is authored and saved through the live Godot Editor:
- All16 catalog pickups have individual native pedestals; existing actor IDs/paths remain intact.
- Hall and all ten rooms use parking `(-3, 0.35, -23)`, clear of displays/exits and near the terminal.
  Native truck compound collision footprint is approximately6m by9.1m.
- NPC absence reproduced in every room: some copied morning schedules selected OUTSIDE;
  other activations were blocked by an unused hall pedestal and floor contact at the spawn.
  Test-only schedules now select STREET in all playable phases; unused room displays are removed
  and home spawns have5cm floor clearance. Production NPC archetypes/schedules are untouched.
- Scythe/axe/throwing-knife scenes have native `strike`/`RESET` clips for visual meshes,
  driven by the existing authoritative strike clock; rigid transforms/colliders are not animated.
- Project-owned native attendance authoring fills the standard MCP nested Resource editing gap.
  It guards canonical room/preset hashes, dirty editor state and production-resource boundaries.

Prior lab follow-up review base: `3b31e1c5b6d928187da8dfa7e7568354c05ababb`.
Prior code/review target: `91ee388ab6e6cd64175866a22ddf537ec8240c79`.
Independent immutable review PASS/no material findings; ARCHITECTURE/STYLE PASS,
reviewer VALIDATION NOT_RUN. Review duration/efficiency NOT_MEASURED.
Prior Windows test-level export and headless menu/level startup120frames PASS:
`.export/windows/20261015-045017Z-91ee388a-r27-lab-presence-pedestals-animations`,
launcher `.export/TEST_LEVEL.cmd`. The build preserves unrelated user edits (`dirty=true`).
Native startup logs are clean; export-process logs retain the live-editor LimboAI DLL-copy
errors and shutdown-only dummy RID retention, so no clean export-process log is claimed.

### Validation

Current follow-up evidence2026-10-15:
- Room bootstrap/supply/participation plus20 real sleep cycles across10 rooms: GUT5/971 PASS,
  `.artifacts/godot_agent/gut-20261015-050930020.stdout.log`.
  The new cycle test first reproduced stuck NIGHT/error30; raw FAIL remains in
  `.artifacts/godot_agent/gut-20261015-050828544.stdout.log`.
- Ordinary saved-night retry/preparation and restore invalidation: GUT19/167 PASS,
  `.artifacts/godot_agent/gut-20261015-051104240.stdout.log`.
- Delivery outcomes/payment failures/night barriers: GUT32/375 PASS,
  `.artifacts/godot_agent/gut-20261015-051116201.stdout.log`.
- Day-cycle fix formatter/incremental architecture/strict architecture/structure PASS;
  fresh-process parser `.artifacts/godot_agent/parsechanged-20261015-051256042.stdout.log`
  and bounded MCP path diagnostics PASS. Early live-reload fallback
  errors were resolved by native path compilation; no new editor log entries.
- Actual combat/three new clip cancellation regressions: GUT16/218 PASS,
  `.artifacts/godot_agent/gut-20261015-044410252.stdout.log`.
- Native preset/editor-only guards/packing: GUT6/284 PASS,
  `.artifacts/godot_agent/gut-20261015-044419569.stdout.log`.
- Actual ten-room scene transitions/reset/cleanup: PASS516 checks/20 entries, exit0;
  `.artifacts/npc-room-followup-20261015.log`, empty stderr.
- Native compound-shape geometry: all16 items supported and truck footprints clear of
  displays/room exits, loading door within15m of terminal; PASS, exit0,
  `.artifacts/lab-geometry-20261015.log`.
- Prior lab native parser and MCP six-script diagnostics PASS; CLI parser
  `.artifacts/godot_agent/parsechanged-20261015-044738493.stdout.log`.
- Incremental formatter, strict architecture and project structure PASS.
  `validate_agent_changes.py` reports the existing editor-only authoring heuristic as REVIEW/FAIL;
  preserve the raw result for current immutable review rather than relabelling it PASS.
- Original count-only GUT2/600 passed while missing actual participation. The strengthened
  regression reproduced all ten failures before repair; raw FAIL logs preserved in
  `.artifacts/godot_agent/gut-20261015-043555594.stdout.log` and `gut-20261015-044040350.stdout.log`.
- Rendered gameplay/visual QA NOT_RUN.

### Prior checkpoint evidence

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

Current day-cycle review BASE `e298932551f16333868ee2208cb14f5b9545b4d7` ->
TARGET `592774eacbe1301c157f12ad2172f34cb91cc508`: no material findings.
Confirmed settlement/reset/preparation/drain gates, configured-path failure handling,
transient preparation ownership, restore invalidation and unchanged closed save schema.

Prior lab review at `91ee388ab6e6cd64175866a22ddf537ec8240c79`: no material findings.
RV-001 remains REJECTED after explicit re-evaluation of the native editor-only authoring
boundary. Current attendance repair confines changes to room/preset Resource graphs,
uses scene-owned UndoRedo and discloses its non-undoable external preset save.
The raw static REVIEW/FAIL is retained; it is not reported as an automatic PASS.

RV-001/P2 — REJECTED: validator heuristic `author` generates scenes. On current code SHA
`25f6de748304171b935dba4084f8de78088f9906`, independent review confirms native editor guard,
saved fingerprint, closed destinations, no overwrite, temporary-Node disposal and plugin cleanup.
Gameplay loads committed editable .tscn; no runtime source generation. This is the explicit
scene-first editor-tooling exception. Raw heuristic FAIL remains recorded, not relabelled PASS.

### Owner QA / blockers

Owner gameplay/visual acceptance of the expanded lab and all ten rooms remains open:
[R27 checklist](../qa_tasks/r27_acceptance.md).

### Next

Owner QA of the updated Windows test build using the expanded [R27 checklist](../qa_tasks/r27_acceptance.md):
finish a shift and sleep through two mornings with renewed supplies; also verify visible usable NPCs
in all phases, truck/terminal/exit access, pedestal pickup/labels and weapon animation feel.
Implementation checks/review/export are complete. Preserve all unrelated user edits.
Required visual/gameplay acceptance remains open; do not archive this task before it closes.
