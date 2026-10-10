# Godot Agent Tooling — editor-owned scenes and MCP-first authoring
Status: **OWNER_QA**

## Goal

Avoid blocking the active Godot 4.7.1 editor through external `.tscn` /
`project.godot` writes, while keeping native headless validation independent
of MCP. Authorize bounded recovery of a confirmed project settings modal,
and project-owned Godot AI MCP extensions.

## Implemented

- `AGENTS.md` routes live scene changes through MCP; no unsafe external-file
  fallback over open editor-owned content.
- `.agents/skills/godot-scene-authoring/SKILL.md` and
  `.agents/skills/godot-ai-mcp/SKILL.md`: native live scene/save, unsaved-state
  guard, safe offline migration, recovery, custom-tool extension policy.
- `.agents/skills/validation-workflow/SKILL.md` requires actual engine checks
  even when MCP is not available.
- `utils/godot_agent.ps1`: pinned 4.7.1 runner for parser, focused GUT,
  import and CLI `SceneTree`/MainLoop scripts; import/mutation refuses an
  active project editor. VS Code tasks delegate to the same runner.
- `.vscode/start-godot.ps1` no longer overwrites Codex's `CODEX_HOME`.
- `.vscode/stop-blocked-godot.ps1`: manually/agent-invoked only after
  confirmed `project.godot` modal, exact PID + `--editor --path` verification,
  evidence logging, optional restart, no blanket process kills.
- Companion `addons/pvz_ai_tools/` registers
  `custom_pvz_editor_ownership` with open/unsaved scene report; scoped,
  read-only, synchronous; does not mutate GECS or gameplay.
- `docs/godot_agent_tooling.md` contains commands and acceptance scenarios.
  Vendored Godot AI / GECS and `project.godot` are untouched.

## Validation

- PASS: GitHub-side cross-file structural checks, VS Code task JSON parsing,
  action names, safety guards, custom-tool registration and ignored logs.
- NOT_RUN: PowerShell parser on Windows (no PowerShell host here).
- NOT_RUN: Godot 4.7.1 parser, native GUT and active editor/MCP QA (no local
  project Godot process accessible in this GitHub-connected session).
- NOT_RUN: independent Codex reviewer. Do not mark DONE without completing
  required project validation/review gates.

## Current / Next

Implementation is present in `dev`. On the owner's Windows project:

1. Run `Godot: Validate changed GDScript` or the explicit
   `utils/godot_agent.ps1 -Action ParseFiles` command, and the focused
   `test_pvz_editor_ownership_tool.gd` GUT test.
2. Open the editor, confirm `custom_pvz_editor_ownership` is available and
   returns changing `unsaved_scenes` values. Verify a disposable open
   scene can be edited/saved through MCP with no external-change modal.
3. Confirm offline import refuses the running editor. With a verified
   project editor PID, test guarded recovery using `-WhatIf` and a foreign
   PID refusal; do not force-kill merely to test.
4. Review the final commit range independently with project workflow;
   triage findings and record actual checks. Owner handles subjective
   editor/visual and gameplay validation.

## Owner QA / blockers

Local Windows/editor acceptance is pending. Unrelated Godot 4.7.1
shutdown-only retained-resource diagnostics remain under the existing
known-engine-limitation policy; do not launch a leak investigation here.
