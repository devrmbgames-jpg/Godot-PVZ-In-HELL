---
name: vscode-workflow
description: >
  Codex/VS Code workflow for this Godot project, including local editor setup,
  context discipline and model/subagent usage.
---

# VS Code / Codex workflow

VS Code is the editor host, not project authority.

## Recommended extensions

- `openai.chatgpt`
- `geequlim.godot-tools`
- `DoHe.godot-format`
- `bitwes.gut-extension`

## Local-only data

Do not commit API keys/tokens, account data, or user-specific absolute debugger/editor paths unless the repository intentionally owns that machine-specific setup.

## Codex context

- Root `AGENTS.md` is a router, not an encyclopedia.
- Resume from `CURRENT_WORK.md` and `PROJECT_INDEX.md`.
- Read only relevant subsystem context/skills.
- See `docs/codex_token_economy.md` for model/subagent strategy.
- Project `.codex/config.toml` configures cheap subagents but intentionally does not choose the main model.

## Editing loop

1. Locate exact owner/contract.
2. Make one coherent change.
3. Format changed GDScript.
4. Run targeted checks/tests.
5. Review targeted diff for unrelated churn.
6. Checkpoint before switching tasks or exhausting context.

Do not modify `.godot/`, imported generated data, extension caches, or `addons/` during ordinary project work.
