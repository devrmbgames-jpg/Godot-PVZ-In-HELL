# Godot Agent Tooling — editor-owned scenes and MCP-first authoring
Status: **IN_PROGRESS**

## Task state

### Goal

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

### Validation

- PASS: native PowerShell parser and four executable runner contracts (selection,
  vendored-addon exclusion, companion inclusion, both editor flags, unverifiable CIM refusal).
- PASS: actual Godot parser for companion ownership tool and GUT; ownership GUT 3/12.
- PASS: live MCP ownership for verified project editor PID 19908; no unsaved scenes.
- PASS: Import refuses the active editor launched with `-e`; no process terminated.
- PASS: structure after restoring task-state headings and replacing nonexistent GUT paths.
- PASS: incremental formatter and architecture-change gates.
- REVIEW_PENDING: scoped runner/MCP companion checkpoint.
- Logs: `.artifacts/godot_agent/`; original-project native editor regression is blocked
  by the live LimboAI DLL. Its failed process alone was stopped; owner editor preserved.

### Current

Baseline: `c8b84b801d674a293d4519e266e2f656883617dd`, `dev`.
The baseline runner had a truncated regex and duplicated tail (10 PowerShell parse errors).
Restored one executable body and recognized `-e` alongside `--editor` for offline guards.
New bounded companion signal verification checks the Direct Traits Inspector in the live
editor without saving scenes/settings or disturbing authored content; nine assertions PASS.

Remaining local acceptance:

1. Confirm `custom_pvz_editor_ownership` reports changing `unsaved_scenes` values.
   Verify a disposable open
   scene can be edited/saved through MCP with no external-change modal.
2. With a verified
   project editor PID, test guarded recovery using `-WhatIf` and a foreign
   PID refusal; do not force-kill merely to test.
3. Review the final commit range independently with project workflow;
   triage findings and record actual checks. Owner handles subjective
   editor/visual and gameplay validation.

### Owner QA / blockers

Local Windows/editor acceptance is pending. Unrelated Godot 4.7.1
shutdown-only retained-resource diagnostics remain under the existing
known-engine-limitation policy; do not launch a leak investigation here.
