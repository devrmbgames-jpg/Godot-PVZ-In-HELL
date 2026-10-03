# PVZ In Hell Simulator

Godot 4.7 + GDScript + GECS v8.

## AI workflow

The repository is optimized for GPT-6.1 Sol in VS Code/Codex without preloading project history.

Default flow:

```text
focused prompt
  -> inspect exact owner + contract
  -> Plan Mode when the task benefits from planning
  -> Goal for the active completion condition
  -> implement
  -> focused review
  -> narrow validation
```

Repository task files are **not** the default planning mechanism. Use `agent_tasks/<task>.md` only when a task must survive another session/thread, is genuinely long/interruptible, or durable tracking was explicitly requested.

Documentation is split by purpose:
- `AGENTS.md` — small always-on correctness and execution rules;
- `PROJECT_INDEX.md` — optional owner/path router;
- `content/ARCHITECTURE.md` — on-demand cross-system gameplay invariants;
- `docs/` — durable design/mechanics documentation;
- `agent_tasks/` — only active durable cross-session implementation state;
- `qa_tasks/` — manual player acceptance;
- Git history — completed implementation history.

## VS Code / Codex / Godot MCP

- GPT-6.1 Sol defaults live in `.codex/config.toml`.
- VS Code Agent Host is enabled in `.vscode/settings.json`.
- Workspace MCP is defined once in root `.mcp.json`; this is the portable Agent Host configuration.
- Godot does not auto-start just because the folder opens. Run the `Godot: Start project editor` task or let the agent start `.vscode/start-godot.ps1` when live MCP context is useful.
- MCP is optional: normal code/search tools remain the default for focused source work.

See `AGENTS.md` for authoritative project rules.
