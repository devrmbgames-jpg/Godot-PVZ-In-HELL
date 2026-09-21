---
name: project-navigation
description: >
  Navigate a large Godot repository with minimal token use using PROJECT_INDEX.md,
  CONTEXT.md routing, targeted symbol searches, and incremental index maintenance.
  Use when locating code, understanding ownership, or when the project has no usable index.
---

# Project navigation

The goal is to find the smallest correct edit surface without scanning the entire project.

## Primary navigation order

1. `CURRENT_WORK.md`
2. root `CONTEXT.md`
3. root `PROJECT_INDEX.md`
4. nearest subsystem `CONTEXT.md`
5. exact implementation file(s)
6. direct callers/callees only

Do not recursively read the whole project to "build context."

## If `PROJECT_INDEX.md` exists

Use it as the primary map.

Start from the canonical file/path relevant to the task and inspect:
- the requested symbol;
- its data contract;
- its direct owner;
- direct callers/callees;
- tests for that behavior.

Expand outward only when evidence requires it.

## If the index is missing

Create a **small canonical index** before broad exploration.

Use only cheap discovery:
1. read `project.godot`;
2. inspect top-level directories;
3. locate existing `CONTEXT.md`, `AGENTS.md`, `README`, test roots, and dependency roots;
4. search exact names relevant to the current task (`class_name`, known component/system names);
5. record only canonical entry points discovered.

Do not enumerate and read every `.gd`, `.tscn`, `.tres`, or asset file.

## If the index is stale

Patch only the affected rows. Do not regenerate the whole index unless the architecture actually changed.

## Index content

`PROJECT_INDEX.md` should contain:
- project-owned subsystem roots;
- canonical files/contracts;
- task -> context routing;
- dependency pins/paths;
- canonical validation commands.

It should **not** contain:
- every source file;
- generated/imported files;
- raw assets;
- full dependency trees;
- function-by-function descriptions;
- copied code.

## Search strategy

Prefer:
1. exact file path from index;
2. exact class/function/component name;
3. direct references to that symbol;
4. narrow directory search;
5. broad search only as a last resort.

After finding the owner, stop exploring unrelated matches.

## Addons boundary

`addons/` is read-only unless the user explicitly requests addon/dependency work.

You may inspect addon code to verify an API, but never patch, format, rename, refactor, or upgrade it as part of normal project work.
