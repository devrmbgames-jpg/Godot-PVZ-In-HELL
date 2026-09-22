---
name: project-navigation
description: >
  Navigate this Godot repository with minimal token use using CURRENT_WORK,
  PROJECT_INDEX, targeted searches, and evidence-driven expansion.
  Use when locating code, ownership, references, or canonical contracts.
---

# Project navigation

Goal: find the smallest correct edit surface, not build a mental copy of the repository.

## Search order

1. `CURRENT_WORK.md`.
2. `PROJECT_INDEX.md`.
3. Exact path/symbol named by the task/checkpoint.
4. Relevant subsystem `CONTEXT.md` only if the contract is still unclear.
5. Direct data contract + owner + callers/callees/tests.
6. Broader search only when a specific missing fact requires it.

Root `CONTEXT.md` is not mandatory for every small task.

## Investigation budget

Before forming the first working hypothesis, normally inspect at most 6–8 implementation files.

Before expanding further, name the missing fact you are trying to prove. Search only for that fact.

Stop when you know:
- authoritative owner;
- data/state contract;
- mutation/execution path;
- direct regression surface.

## Search strategy

Prefer, in order:
1. exact indexed path;
2. exact class/function/component/resource name;
3. direct references;
4. narrow directory search;
5. broad search as last resort.

For large `.tscn` files, find the exact node/subresource/NodePath first. Do not dump the full scene unless its complete structure is actually required.

Do not:
- recursively read directories;
- enumerate every source file;
- reread unchanged files already summarized in `CURRENT_WORK.md`;
- inspect roadmap docs unless the active task depends on them;
- inspect `addons/` except to verify a specific pinned API.

## PROJECT_INDEX maintenance

Keep the index canonical and small. Patch only affected rows.

Include subsystem roots, canonical contracts, dependency pins, and validation entry points. Do not add asset manifests, generated files, copied code, or function-by-function descriptions.

## Subagent use

If discovery is likely to require several reads but no architectural decision, prefer the project `explorer` subagent. It should return concise paths/evidence to the main agent rather than forwarding full file contents.
