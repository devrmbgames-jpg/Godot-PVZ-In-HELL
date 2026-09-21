---
name: vscode-workflow
description: >
  Work on a Godot project through VS Code with Codex, Godot Tools, GDScript Formatter,
  and optional GUT integration. Use when setting up the editor, debugging LSP/extensions,
  or preparing the local Codex workflow.
---

# VS Code workflow

VS Code is the editor host, not project authority.

## Recommended extensions

- `openai.chatgpt`
- `geequlim.godot-tools`
- `DoHe.godot-format`
- `bitwes.gut-extension`

## Local-only settings

Do not commit:
- absolute Godot executable paths;
- API keys/tokens;
- account data;
- user-specific debugger/launch paths.

## Codex context discipline

- Use `AGENTS.md` as the router instead of pasting architecture into every prompt.
- Read only relevant subsystem context and skills.
- For long work, update `CURRENT_WORK.md`.
- Keep source-of-truth decisions in `CONTEXT.md`/docs, not only chat.

## Editing loop

1. Inspect diagnostics.
2. Make one coherent change.
3. Format changed GDScript.
4. Run targeted static checks/tests.
5. Review diff for unrelated scene/formatter churn.
6. Update checkpoint before switching tasks or exhausting context.

Do not modify `.godot/`, imported generated data, or extension caches.
