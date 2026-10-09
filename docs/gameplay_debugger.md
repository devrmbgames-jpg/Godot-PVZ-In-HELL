# Gameplay Debugger

Open the existing developer console and enter `debug_inspect target`, `debug_inspect self`,
or `debug_inspect entity:<id>`. `debug_targets` lists handles. The native panel also accepts
the existing package/visit target syntax when a physical Entity exists. Exact Entity IDs
include registered dormant bodies; inspecting them never enables participation.

Select chooses a weak Entity reference. Refresh captures a new snapshot explicitly.
Closing the panel or console releases the selection. Removed actors become UNAVAILABLE;
an actor with a reused ID is never silently substituted into the retained selection.
The console continues to own keyboard, mouse and close behavior. There is no extra InputMap
action, modal gameplay owner or frame polling.

The panel shows current Component type names, live Relationship labels, incoming/outgoing
Smart Object reservation owner/object/slot/token, native LimboAI status and Brain node,
and the last 24 matching entries from the existing bounded BoundaryTrace. Events match
Entity, NPC, package and current visit identities, including selected outgoing operations.
Snapshots contain detached scalar/container values and no live Object references.

For district NPCs it also shows the actual roster obligation/day/phase/completion, decision
owner and behavior, selection and terminal action reasons, generation/status, movement and
look Intent, perception summary and physical/cadence participation. Existing diagnostics
remain the provider of decision reasons. Components, Relationships and roster data remain
the authorities; this panel does not advance a tree, reserve a slot, change a goal or write
gameplay state. Detailed tree inspection uses the native LimboAI debugger for the displayed
Brain node and instance, rather than another tree inspector.

Layout is editable in `content/debug/gameplay_debugger_view.tscn`. Dynamic Tree rows are
presentation only. The console adapter owns command registration and panel teardown.

Headless provider and lifecycle regressions: `tests/gut/test_gameplay_debugger.gd`.
Owner editor QA must check readable scale and clipping, mouse/keyboard navigation,
refreshing a live/dormant NPC, closing the console, and the native LimboAI integration.
