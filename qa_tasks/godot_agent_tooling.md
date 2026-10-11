# Godot agent tooling — owner acceptance

Owning task: [Godot Agent Tooling](../agent_tasks/godot_agent_tooling_integration.md).
Status: **PENDING**.

Native CLI and live MCP acceptance passed. The MCP-created disposable scene
`res://tests/artifacts/editor_ownership_acceptance.tscn` saved and reopened;
ownership reported clean → unsaved → clean. The original main menu was restored.
No rendered playtest or actual process termination was performed.

- [ ] Confirm scene editing/saving through MCP is comfortable in the normal editor
  workflow and preserves authored content and unsaved user changes.
- [ ] Confirm normal editor/VS Code tooling use does not introduce external-change
  modal stalls. Follow [tooling scenarios](../docs/godot_agent_tooling.md) for
  controlled disposable-content checks if needed.
- [ ] Confirm the recovery workflow is understandable: verified project PID,
  concrete modal evidence, warning about unsaved changes, and guarded launcher.
  Successful `-WhatIf` and foreign-process refusal already passed; do not kill
  an editor merely to test recovery.

Record required acceptance or explicit deferral in the owning task before DONE/archive.
