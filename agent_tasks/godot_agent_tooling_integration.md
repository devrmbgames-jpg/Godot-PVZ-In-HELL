# Godot Agent Tooling — acceptance checkpoint
Status: **OWNER_QA**

## Goal
Use native Godot AI MCP to edit scenes that are open in Godot, keep headless
Godot verification independent of MCP, and allow project-scoped recovery from
confirmed `project.godot` modal blockage. Do not rewrite open scenes externally.

## Implemented
The feature and its permanent policies are implemented in `dev`. There is
no additional Godot tooling feature planned by this task.

- `AGENTS.md`, `.agents/skills/godot-scene-authoring/SKILL.md`,
  `.agents/skills/godot-ai-mcp/SKILL.md` and
  `.agents/skills/validation-workflow/SKILL.md` define the routing and safety rules.
- `utils/godot_agent.ps1` and `.vscode/tasks.json` expose headless parser,
  GUT, import and guarded offline operations. `.vscode/start-godot.ps1`
  avoids modifying only Godot's `CODEX_HOME`.
- `.vscode/stop-blocked-godot.ps1` targets a verified PID and project path,
  logs evidence and warns about losing unsaved editor changes.
- `addons/pvz_ai_tools/editor_ownership_tool.gd` registers the read-only
  `custom_pvz_editor_ownership` MCP tool, with focused GUT tests.
- Commands, caveats and acceptance procedures live in
  [Godot agent tooling](../docs/godot_agent_tooling.md).

The corrupted duplicate block in `utils/godot_agent.ps1` (introduced in the
addon-filter edit) was repaired at `ff8c7d7fde8023ea9452a20dec6c75e5298cdd8f`.
The restored source has one each of `ParseChanged`, `GUT` and `OfflineScript`
actions. This static inspection does **not** establish PowerShell/Godot PASS.

## Validation
- **PASS (static only):** GitHub-side JSON, paths and registration checks;
  reconstructed CLI script sanity check after the repair.
- **NOT_RUN:** Windows PowerShell syntax/execution, Godot 4.7.1 parser and
  `test_pvz_editor_ownership_tool.gd` GUT.
- **NOT_RUN:** live editor/MCP ownership + unsaved scenes, safe modal
  recovery `-WhatIf` / foreign PID refusal, independent Codex review.
- Do not classify unrun tests or editor QA as PASS.

## Current / Next
No new implementation milestone. On the owner's local Windows project:

1. Run the pinned Godot CLI runner and focused GUT; repair any real defects.
2. Confirm live MCP registration and save of a disposable open scene; verify
   `custom_pvz_editor_ownership` changes with unsaved scene state.
3. Verify offline import refusal with an open editor; use `-WhatIf` for
   blocked-editor recovery (never force-kill solely as a test).
4. Review immutable changes, triage findings and archive this task only when
   required native validation and review pass. Record manual visual QA
   separately under `qa_tasks/` if it remains outstanding.

## Owner QA / blockers
Windows editor/MCP and PowerShell/Godot runtime are not available in this
GitHub-only session. Do not treat ordinary Godot 4.7.1 shutdown-only retention
warnings as a new runtime leak investigation.
