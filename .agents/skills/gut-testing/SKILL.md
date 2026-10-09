---
name: gut-testing
description: >
  Use only when authoring, modifying, or explicitly running GUT tests for this Godot 4.7 project.
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

In durable tasks, replace the relevant validation checkpoint with its current result and log
reference; do not append one entry per run or diagnostic trial. GUT assertions and exit zero
do not excuse parser/runtime/ownership errors. Shutdown ObjectDB/Resource/RID retention alone
is a diagnostic baseline, not proof of a memory leak or an automatic task blocker; retain it
in logs and apply [the memory acceptance policy](../../../AGENTS.md#validation-and-commits).
Godot 4.7.1's specified shutdown-only engine retention category is
`KNOWN_ENGINE_LIMITATION / DEFERRED`: do not block tasks, start an investigation or require
another growth run solely for those warnings. Reconsider only after the project moves to
stable Godot 4.8+ and relevant upstream fixes are checked. Runtime defects remain failures.
For lifetime checks, warm up then repeat equivalent operations 50–100 times in one process,
settle deletion/deferred work and compare memory/object trends against the same baseline.
Bound the test's own assertion history and samples so instrumentation cannot imitate a leak.
Classify unfamiliar failures before adding them to the task scope; do not suppress warnings.
