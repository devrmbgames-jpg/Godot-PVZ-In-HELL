---
name: gut-testing
description: Use when creating, modifying or executing focused GUT tests in this Godot 4.7 project.
---

# GUT testing

Project GUT is pinned to 9.7.1. Do not install or upgrade it during unrelated work.

## Test shape

- Pure deterministic logic -> unit test.
- GECS ordering, Nodes, Resources, signals, or physics -> focused integration test.
- One test should prove one behavior/regression.
- Prefer minimal real objects; double only expensive/nondeterministic boundaries.
- For GECS, create only the Components/Entities required by the behavior.
- Avoid arbitrary sleeps; wait on concrete signals/frames/conditions with bounded timeout.

## Execution

Do not run GUT after every edit or milestone. For a complete large `Rxx` / `Rxx.x` task, normally run the relevant regression surface once near completion. An explicit user request or blocking bug may justify one earlier narrow run.

Use headless Godot 4.7. Return only command + concise totals on success; on failure return the failing test/assertion and smallest useful stack. Never paste the full GUT log into the main context.

Rendered/visual validation is not part of GUT execution unless the user explicitly approves it for the current task.

Record only the current test evidence in an owning durable task according to
[task-lifecycle](../task-lifecycle/SKILL.md); do not append each trial to an activity log.
Assertions and exit zero do not excuse parser/runtime/ownership defects. For actual
memory/lifetime acceptance or shutdown-only retention warnings, consult
[memory diagnostics](../validation-workflow/references/memory-lifetime.md).
