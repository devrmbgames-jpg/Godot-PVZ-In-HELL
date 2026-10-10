# Godot-first agent tooling: editor ownership, CLI and recovery

This is the operational contract for Codex / VS Code in PVZ In Hell.
The short routing rule lives in `AGENTS.md`; detailed constraints live in
`.agents/skills/godot-scene-authoring/SKILL.md`,
`.agents/skills/godot-ai-mcp/SKILL.md` and
`.agents/skills/validation-workflow/SKILL.md`.

## Choose by file ownership, not by MCP availability

| Work | Editor running / scene open | Editor closed / offline |
| --- | --- | --- |
| Change a scene's nodes, physics, exported values, sub-scenes | Godot AI MCP native scene/node/resource tools; save in editor | Native Godot scene/resource API, preferably via batch `SceneTree` script; focused raw text diff only for a provably closed scene |
| Change an editor-owned `.tres` | Godot editor-native resource operations, respecting unsaved changes | Native resource API / focused file edit |
| Change `project.godot` | Godot ProjectSettings via MCP/editor; external writes forbidden | Native Godot tooling only with editor closed |
| Change `.gd` | Codex/VS Code file edit, optionally MCP script diagnostics | File edit + headless parser |
| Verify a code change | MCP diagnostics if connected **plus** native GUT/CLI when required | Native headless parser/GUT/smoke |
| Mass-migrate scenes | Prefer native editor operations or pause editor and go offline | Bounded `SceneTree`/`MainLoop` script using `PackedScene`/`ResourceSaver` |

**MCP does not make direct disk writes safe.** `filesystem_manage(write_file)`
and `script_patch` write bytes on disk, while `node_create` /
`node_set_property` edit the live Godot scene with Editor UndoRedo.
Do not use direct-file MCP commands to overwrite an open `.tscn`.
`scene_open(force_reload=true)` can discard unsaved scene changes; do not
use it automatically.

Before live-scene changes, call `custom_pvz_editor_ownership` when available.
It exposes `current_scene`, `open_scenes`, `unsaved_scenes` and
`current_scene_unsaved` using Godot 4.7's editor API. Avoid destructive
switch/reload while any affected scene has unknown or unsaved changes.
This covers scene dirtiness, not unsaved data inside every plugin.

For repetitive native edits, use small `batch_execute` transactions.
Only actual UndoRedo commits can be rolled back; do not treat arbitrary
filesystem/resource operations as atomic.

## Codex / Godot AI connection

- Live editing requires the GUI Godot Editor and the `godot-ai` MCP bridge.
  Start the project's editor via `.vscode/start-godot.ps1 -ProjectRoot .`
  when needed; avoid duplicate editors.
- The launcher intentionally **does not** change `CODEX_HOME` by itself.
  Codex and Godot AI must resolve the *same* user-level or explicit
  `CODEX_HOME` configuration. Check the active Codex MCP tool list rather
  than assuming the server is connected because the Godot plugin is enabled.
- A missing MCP bridge is not a reason to skip parser/GUT validation.
  It is also not permission to rewrite a scene currently open in the editor.
- VS Code's Godot Tools, formatter and Problems panel are useful to a human;
  extension installation alone does not expose LSP diagnostics as Codex tools.

## Local command-line validation (Windows PowerShell)

The runner locates Godot 4.7.1 from `-GodotPath`, `GODOT_BIN`,
`.bin/` or PATH and prefers a console executable on Windows.
It requires the pinned Godot version. Logs go to ignored
`.artifacts/godot_agent/`.

```powershell
powershell -NoProfile -File .\utils\godot_agent.ps1 -Action Version
powershell -NoProfile -File .\utils\godot_agent.ps1 -Action ParseChanged
powershell -NoProfile -File .\utils\godot_agent.ps1 -Action ParseFiles -Paths res://content/shared/services/entity_composition_service.gd
powershell -NoProfile -File .\utils\godot_agent.ps1 -Action GUT -TestPath res://tests/gut/test_entity_build_rules.gd
powershell -NoProfile -File .\utils\run_smoke.ps1 -Name district
```

Importing and offline scene migration **must not** run alongside this
project's GUI editor (the runner checks for it). A CLI script must extend
`SceneTree` or `MainLoop`. Scripts extending `EditorScript` run from
the live Godot script editor's File → Run command, not `--script`.

```powershell
powershell -NoProfile -File .\utils\godot_agent.ps1 -Action Import
powershell -NoProfile -File .\utils\godot_agent.ps1 -Action OfflineScript -ScriptPath res://utils/my_scene_migration.gd
```

Equivalent VS Code tasks are defined under `.vscode/tasks.json`.
Run focused validations after coherent edits rather than invoking Godot
after every small source patch. Never call a formatter or static audit
a native Godot PASS.

## Confirmed project.godot modal: emergency recovery

The existing Godot 4.7.1 editor can block on `project.godot` external-change
dialogs. Editor-native `ProjectSettings.save()` reduces conflicting external
writers, but **does not guarantee** that no modal can occur.

The owner authorizes agents to terminate this project's editor **only when
the project.godot modal is actually confirmed and blocks work**. Prefer
ordinary save/close if the editor is responsive. A generic MCP timeout
or missing plugin is *not* confirmation.

1. Gather evidence: the owner's report, a scoped editor log or an explicit
   error/dialog observation. Check whether `project.godot` changed in content
   or merely timestamp; do not blindly roll back unrelated changes.
2. Identify exactly one editor PID for this project. The guarded script
   additionally requires `--editor --path <this-repository>` in its
   command line; a missing or ambiguous identity is a refusal.
3. Warn that a forced stop discards **unsaved editor state**. Run the helper
   with the exact PID and concrete evidence. It does not kill all Godot
   instances and does not click "Ignore External Changes".
4. Review the cause before re-opening. If appropriate use `-Restart` to
   restart via the project launcher. No repeated blind restart loop.

```powershell
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -match '^Godot.*\.exe$' -and $_.CommandLine -match '--editor' } |
  Select-Object ProcessId, CommandLine

# Example: substitute the verified PID and specific observed evidence.
.\.vscode\stop-blocked-godot.ps1 -EditorPid 12345 -Evidence "Observed blocked project.godot external-change dialog in project editor" -Restart

# Dry run without termination:
.\.vscode\stop-blocked-godot.ps1 -EditorPid 12345 -Evidence "Observed blocked project.godot external-change dialog in project editor" -WhatIf
```

The helper logs attempted and completed actions in
`.artifacts/godot_agent/editor-recovery.jsonl`.
It does not search for a process to kill automatically. It fails closed
when the PID or exact project path is unverified.

## Allowed Godot AI extensions

When the installed `addons/godot_ai/tool_catalog.gd` lacks a required
operation, Codex may build a narrow project-owned companion tool in
`addons/pvz_ai_tools/`. Use its supported
`McpCustomToolSpec` / `McpToolRegistry` entry points with correct
`requires_writable`, UndoRedo/deferred contracts, lifecycle teardown and
focused tests. Keep vendored Godot AI and GECS unchanged.

Current GECS custom tools are read-only; adding mutation capabilities
requires a new, explicit, tested contract, not repurposing inspection.

## Required local acceptance

- In an open, disposable `.tscn`, edit a node and a sub-scene instance via
  MCP, save in editor, reopen and verify native ownership/UID/UndoRedo;
  check that no unexpected external-change modal appeared.
- Make a controlled external change to a **disposable** open scene and verify
  the policy disallows repeating it in agent work; do not experiment on
  unsaved gameplay scenes.
- Verify `ParseFiles` with a correct script and a deliberately broken test
  script, plus a focused GUT run.
- Verify `Import` / `OfflineScript` explicitly refuse to run while the
  project editor is open.
- With the editor open, test `stop-blocked-godot.ps1 -WhatIf` against the
  exact project PID, and verify it refuses an unrelated PID. Do **not**
  force-kill the editor just to test the helper.
- In a disposable project/configuration, confirm editor-native ProjectSettings
  updates preserve values across editor restart without external writes.
- In real Codex VS Code, verify Godot AI MCP tools and native Godot CLI both
  work; report untested visual/modal behavior as OWNER_QA.

These are acceptance scenarios, not claimed results. The repository change
alone cannot prove GUI/MCP behavior on the owner's Windows machine.
