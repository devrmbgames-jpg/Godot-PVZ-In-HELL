# R27.5 — полный тестовый зал и10 изолированных NPC-комнат

Status: **DONE** — принято владельцем 2026-10-15.

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

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Owner parcel-content finding2026-10-15 is repaired; implementation checks/review/export complete.
Owner confirmed separate room catalogs; Creepy and Lost keep the general catalog.
Vampire uses blood flask/barrel; Fire Elemental uses fire flask/barrel; Shy uses working clothes.
Other rooms expose their existing preferred categories, including clothing where authored.
The original category-weighted deterministic order owner is unchanged; room catalogs are
editable native Resource data, not item-ID branches in the runtime order algorithm.
Clothing was absent from the old16-item catalog, forcing Shy's fallback. Vampire had empty
weights, allowing knife/acid. Universal identical contents across all10 rooms was not reproduced.
Existing cloth_sample is now an orderable physical inventory item, preserving its scene path.
All10 scene/preset catalogs were saved through the live editor; all open scenes remain clean.
The bounded companion supply tool fills the scripted nested Resource editing gap, checks
room/preset hashes and ownership, uses scene UndoRedo and discloses non-undoable preset saves.
Production profiles, their weights and the general delivery catalog are unchanged.
Review base: `975961dd05294dae545b56ec7949948c2fd253cf`.
Code/review target: `2d4041f185c7a9464f0a8ea199b00cdd8c8561b7`.
Independent immutable review: no material findings; ARCHITECTURE/STYLE PASS,
reviewer VALIDATION NOT_RUN. Review duration/efficiency NOT_MEASURED.
Windows QA export and headless menu/level startup120frames PASS:
`.export/windows/20261015-053501Z-2d4041f1-r27-npc-parcel-assortments`,
launcher `.export/TEST_LEVEL.cmd`; dirty=true preserves unrelated owner edits.
Actual startup logs are clean. Export-only shutdown retention remains
KNOWN_ENGINE_LIMITATION/DEFERRED; no clean export-process log is claimed.

Earlier repaired lab scope remains awaiting owner visual/gameplay acceptance:
- All16 catalog pickups have individual native pedestals; actor IDs/paths are preserved.
- Hall and ten rooms use parking `(-3, 0.35, -23)`, allowing the truck's6m by9.1m footprint.
- Test-only schedules keep NPCs on STREET in playable phases; unused displays were removed
  and home spawns have5cm floor clearance. Production schedules remain untouched.
- Scythe/axe/throwing knife have native visual-mesh strike/RESET clips driven by the strike clock.
- No-save rooms complete mandatory evening settlement/reset/morning preparation/command draining
  before MORNING; transient preparation is separate from disk-save success and reset by restore.
Rendered owner QA remains open.

### Validation

Current assortment evidence2026-10-15:
- Authored room catalogs, three daily native batches, repeat-entry determinism, actual physical
  unpacking/history and prior20 real sleep cycles: GUT6/1354 PASS,
  `.artifacts/godot_agent/gut-20261015-053159417.stdout.log`.
- Native authoring guards/catalog preflight/preset packing: GUT7/293 PASS,
  `.artifacts/godot_agent/gut-20261015-053227200.stdout.log`.
- Actual package contents and hazards: GUT14/244 PASS,
  `.artifacts/godot_agent/gut-20261015-053228673.stdout.log`.
- General category-weighted order selection: GUT7/201 PASS,
  `.artifacts/godot_agent/gut-20261015-053257010.stdout.log`.
- Formatter, strict architecture, structure, native parser/MCP four-script diagnostics PASS;
  `.artifacts/godot_agent/parsechanged-20261015-053234904.stdout.log`.
  One temporary plugin reload parse error during registration edit was resolved; final diagnostics
  are checked/empty. The editor-only authoring heuristic remains raw REVIEW/FAIL for review.
- Baseline test reproduced Shy's unavailable category and fallback; raw FAIL retained:
  `.artifacts/godot_agent/gut-20261015-052506260.stdout.log`. Initial assertions requiring
  preferences for neutral profiles were corrected to the actual category fallback contract.

Prior follow-up evidence2026-10-15:
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

Current assortment review BASE `975961dd05294dae545b56ec7949948c2fd253cf` ->
TARGET `2d4041f185c7a9464f0a8ea199b00cdd8c8561b7`: no material findings.
Confirmed ten scene/preset catalog pairs, bindings, physical clothing, unchanged runtime
selection and production profiles/catalogs. RV-001 re-evaluated and remains REJECTED:
new catalog mutation preserves fixed native editor-only asset boundaries and explicit save semantics.

Prior day-cycle review BASE `e298932551f16333868ee2208cb14f5b9545b4d7` ->
TARGET `592774eacbe1301c157f12ad2172f34cb91cc508`: no material findings.
Confirmed settlement/reset/preparation/drain gates, configured-path failure handling,
transient preparation ownership, restore invalidation and unchanged closed save schema.

Prior lab review at `91ee388ab6e6cd64175866a22ddf537ec8240c79`: no material findings.
RV-001 remains REJECTED after explicit re-evaluation of the native editor-only authoring
boundary. Prior attendance repair confines changes to room/preset Resource graphs,
uses scene-owned UndoRedo and discloses its non-undoable external preset save.
The raw static REVIEW/FAIL is retained; it is not reported as an automatic PASS.

RV-001/P2 — REJECTED: validator heuristic `author` generates scenes. On prior code SHA
`25f6de748304171b935dba4084f8de78088f9906`, independent review confirms native editor guard,
saved fingerprint, closed destinations, no overwrite, temporary-Node disposal and plugin cleanup.
Gameplay loads committed editable .tscn; no runtime source generation. This is the explicit
scene-first editor-tooling exception. Raw heuristic FAIL remains recorded, not relabelled PASS.

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Связанные чеклисты: [R27 checklist](../../qa_tasks/r27_acceptance.md)

### Next

Задача закрыта и архивирована. Возобновление этой реализации не требуется; обнаруженные впоследствии дефекты оформляются отдельными задачами.
