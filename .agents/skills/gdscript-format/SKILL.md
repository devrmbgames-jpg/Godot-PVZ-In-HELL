---
name: gdscript-format
description: >
  Format and lint project GDScript with GDQuest GDScript Formatter and VS Code integration.
  Use after editing .gd files, when formatting differs, when style checks fail, or when
  configuring DoHe.godot-format.
---

# GDScript Formatter

Use the GDQuest GDScript Formatter for project-owned GDScript.

Do not silently install/upgrade tooling during an unrelated task.

## Scope

Format changed project-owned `.gd` files first, not the whole repository.

**Never format anything under `addons/` unless the user explicitly requests addon/dependency work.**

Do not format vendored addons/submodules during normal project work.

## CLI workflow

If `gdscript-formatter` is available:

```bash
gdscript-formatter --check path/to/changed.gd
gdscript-formatter path/to/changed.gd
gdscript-formatter --verify-structure path/to/changed.gd
```

If unavailable, report formatting validation as not run.

## Policy

- Follow formatter output rather than hand-aligning code.
- Preserve semantics.
- Keep structure verification enabled.
- Keep code reordering disabled by default unless the project explicitly adopts it.
- Avoid formatting unrelated files.

## VS Code

Recommended extension: `DoHe.godot-format`.

Keep machine-specific executable paths out of git.
