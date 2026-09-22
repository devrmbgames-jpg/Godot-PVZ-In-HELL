---
name: gut-testing
description: >
  Add and run GUT tests for Godot 4.7, including unit/integration tests, doubles,
  CLI runs, and VS Code GUT integration. Use when adding tests, fixing regressions,
  installing GUT, or validating gameplay Systems/helpers.
---

# GUT testing

Do not invent passing test results or silently add GUT during unrelated work.

## Version contract

For **Godot 4.7.x**, use a GUT release that explicitly supports Godot 4.7.
GUT 9.7.1 / `godot_4_7` is a known compatible line.

Do not install GUT `main` just because it is newer.

## Execution cadence

GUT execution is intentionally **batched** to conserve token allowance and runtime/log churn.

Default policy:
- do not run GUT after every edit, file, milestone, or local commit;
- do not run a growing regression suite repeatedly while implementing one roadmap task;
- write/update tests as needed during implementation, but normally execute them once near the end of the complete `Rxx` / `Rxx.x` task;
- pair that final GUT run with the relevant headless smoke/runtime validation;
- milestone commits rely on static/deterministic validation instead.

Early execution is an exception only when:
- the user explicitly asks to run tests now; or
- a concrete blocking bug cannot be diagnosed or validated without one narrow targeted test.

After such an exception, return to the normal cadence; do not rerun the full suite after every follow-up edit.

## Strategy

- Pure deterministic logic -> unit tests first.
- GECS ordering, Godot Nodes, Resources, signals, physics -> integration tests.
- One test = one behavior/regression.
- Arrange -> act -> assert.
- Prefer real lightweight objects.
- Use doubles/spies at expensive/nondeterministic boundaries.
- For bug fixes, add a regression test when practical.
- Avoid arbitrary sleeps; await concrete signals/frames/conditions with bounded timeout.

## Visual-run boundary

Test validation must remain non-visual by default. Do not launch rendered Godot or capture screenshots while running or debugging tests unless the user explicitly approves visual validation in the current task/conversation.

If a failure can only be reproduced visually, report the non-visual evidence and mark the visual check `NOT RUN — user visual validation required`.

## CLI

Typical GUT CLI entry point:

```bash
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd
```

For CI/headless, use the local Godot 4.7 executable with headless mode.

Prefer a committed `.gutconfig.json` once the project adopts GUT.

## GECS tests

- Test System behavior through minimal matching entities/components.
- Test Observer behavior by triggering the actual transition.
- Test order-sensitive mechanics with explicit setup/order.
- Do not test GECS internals unless reproducing a project-facing dependency bug.

Always report the exact command and failure category.
