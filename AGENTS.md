# Codex / Agent Instructions

This is the small always-loaded router. Detailed rules live in skills/docs and must be loaded only when relevant.

## Start / resume

1. Read `CURRENT_WORK.md`.
2. Read `PROJECT_INDEX.md`.
3. If an active checkpoint names exact docs/files, use those first.
4. Read root or subsystem `CONTEXT.md` only when the task needs its architecture/dependency/validation facts.
5. Load at most two relevant skills initially; add another only when the task crosses that boundary.
6. Inspect exact symbols/paths and direct callers/callees/tests only.

Do not automatically reread roadmap docs, root CONTEXT, unchanged files already summarized in CURRENT_WORK, or unrelated tests/assets.

## Skill router

- Any project code/architecture change: `.agents/skills/project-rules/SKILL.md`
- Repository discovery/navigation: `.agents/skills/project-navigation/SKILL.md`
- Godot 4.7 APIs/scenes/physics: `.agents/skills/godot-4-7/SKILL.md`
- GDScript: `.agents/skills/gdscript-style/SKILL.md`
- GECS v8: `.agents/skills/gecs-v8/SKILL.md`
- Formatting/lint: `.agents/skills/gdscript-format/SKILL.md`
- Tests: `.agents/skills/gut-testing/SKILL.md`
- Game design: `.agents/skills/professional-game-design/SKILL.md`
- Long/multi-session work: `.agents/skills/agent-continuity/SKILL.md`
- Codex/VS Code workflow: `.agents/skills/vscode-workflow/SKILL.md`
- Token/model strategy: `docs/codex_token_economy.md`

## Hard boundaries

- `addons/` is read-only unless the user explicitly requests dependency/addon work.
- Target the repository-declared engine/framework versions; currently Godot 4.7 and pinned GECS v8 source are authority.
- Godot physics bodies own physical transform/velocity unless a documented contract says otherwise.
- Static typing is required for project GDScript.
- Relationship/owner-link data belongs in `content/relationships/<subsystem>/`, with `r_*.gd` filenames and `R_*` classes, even when GECS requires the `Component` base. Keep ordinary actor/effect state in `components/` with `C_*`.
- GDScript visibility is naming-based: private members/helpers start with `_`; public members/functions and `@export` fields do not. Signal slots use the `_on_` prefix. Constants use `UPPER_SNAKE_CASE`.
- Every project-owned script has a short responsibility description; public API and authored/exported configuration use useful `##` Godot doc-comments.
- GDScript functions must be visually split into semantic blocks with single blank lines. Simplify dense boolean expressions with named predicates, clear nested `if`s, or private helpers; avoid redundant/misleading casts.
- No magic gameplay constants; use named constants/data.
- **Systems are atomic. A project `System` must not call another `System` as a service/helper.** Use `deps()` for ordering and Components/Relationships/typed events for data flow.
- **Reserve `S_*` / `extends System` for real GECS-scheduled work.** Static-only physics solvers, helpers and domain services are non-System classes; do not keep registered no-op System nodes or scan `ECS.world.systems` as a service locator.
- System queries are data contracts: required hot-path Components belong in `with_all(...).iterate(...)`; avoid repeated `get_component()` inside System loops when GECS can provide them.
- Split monolithic Systems by component set/responsibility instead of branching over optional Components.
- Physics integration is the only exception at the Entity callback boundary: a RigidBody/physics Entity may forward its Godot physics callback to multiple independent solvers, but those solvers must not call each other.
- Never claim a formatter/test/Godot run passed unless it actually ran.
- Never discard user edits, force-push, rewrite unrelated history, or upgrade dependencies unless requested.
- Never write authored files into `.godot/`.
- **Never launch Godot in rendered/visual mode, capture screenshots, record the screen, or perform visual UI/scene inspection unless the user explicitly approves visual validation in the current task/conversation.** Visual validation is user-owned by default.
- Headless Godot, GUT, smoke tests, deterministic scripts, formatter/lint, and concise logs remain allowed unless the user restricts them separately.
- If a task has a visual acceptance criterion but visual validation was not explicitly approved, validate everything possible non-visually and report the visual portion as **NOT RUN — user visual validation required**. Do not ask for permission unless visual validation is actually necessary to proceed.

## Token / investigation budget

Before the first working hypothesis, normally inspect no more than 6–8 implementation files.

If more context is required:
- identify the exact missing contract/fact;
- expand only toward that evidence;
- do not recursively scan directories or read the repository file-by-file.

Prefer exact search, targeted ranges, targeted diff, and relevant error output. For large `.tscn` files, locate the required node/subresource instead of dumping the whole scene.

Stop exploring once the owner, data contract, and direct regression surface are known.

## Model / subagent policy

The main session owns architecture and final decisions.

When subagents are available, delegate work that does not need the main model:
- `explorer`: narrow repository discovery/read-only evidence;
- `mechanical_worker`: bounded implementation after architecture is already decided;
- `reviewer`: focused review of a concrete diff;
- `docs_scout`: narrow documentation/reference lookup;
- `validator`: run deterministic checks/tests and compress noisy output into concise PASS/FAIL evidence without editing authored source.

### Strict sequential subagent policy

Daily token allowance is more important than wall-clock speed in this repository.

- Spawn **at most one subagent at a time**.
- Always wait for that subagent to finish and integrate its concise result before deciding whether another subagent is needed.
- Never run subagents in parallel, including read-only `explorer`, `docs_scout`, `reviewer`, or `validator` roles.
- Do not pre-spawn speculative agents for possible future work.
- Prefer one well-scoped delegation over several overlapping delegations.
- After each subagent result, first decide whether the main agent can finish directly; spawn another only if it still saves meaningful context/tokens.
- Only one write-capable worker may ever operate on the working tree, and it must complete before validation/review delegation starts.

The project config enforces this with `agents.max_concurrent_threads_per_session = 1`.

Do not spawn a subagent for a trivial one-file edit. Do not delegate architecture, ownership, physics authority, GECS boundaries, input priority, or cross-system lifecycle decisions just to save tokens.

Project subagent defaults are in `.codex/config.toml`. The project intentionally does not set the main model.

## Roadmap/task IDs

- `Rxx` / `Rxx.x` are the only canonical implementation task/order IDs.
- `ТЗ xx` labels in `docs/roadmap/` are design-source IDs and do not imply implementation order.
- Use [docs/roadmap/README.md](docs/roadmap/README.md) as the canonical mapping. If a human says `RM08`, normalize it to repository ID `R08`; do not create a second RM-prefixed ID.
- Completed implementation tasks are intentionally absent from `agent_tasks/`; confirm them in `task_history.md` instead of recreating task files.

## Work protocol

For sizable work, maintain `WORK.md`. For interruptible work, keep `CURRENT_WORK.md` as a compact durable checkpoint.

**Create a local git commit after every completed logical stage/milestone and before starting the next stage or separate task.**
- A commit must contain one coherent change.
- Milestone commits use cheap validation only: deterministic structure/path checks, formatter/lint when available, targeted static inspection, and `git diff --check`.
- **Do not run GUT suites, headless smoke suites, or repeated runtime validation after ordinary milestones/subtasks.**
- Run GUT + relevant headless smoke/runtime validation once near the end of the complete implementation task (`Rxx` / `Rxx.x`), before marking that task complete.
- Early runtime/GUT execution is allowed only when the user explicitly requests it or when a concrete blocking bug cannot be diagnosed/validated without a narrow targeted run. Do not turn that exception into repeated regression runs.
- Update `CURRENT_WORK.md` before/with the milestone commit if the task continues.
- Do not batch several independent stages into one large commit.
- Do not push, open a PR, or rewrite history unless the user explicitly asks.

Checkpoint only current state, invariants, changed paths, validation, blocker, and one exact next step. Never paste full logs/diffs/source/chat history.

Keep only unfinished task files in `agent_tasks/`. After completion:
- move durable contracts to context/docs;
- append one short dated line to `task_history.md`;
- delete the completed task file;
- return `WORK.md` and `CURRENT_WORK.md` to idle.

Validation should be the narrowest relevant check first. Do not add new GUT suites without explicit user instruction.

### Validation cadence

Before an ordinary milestone/subtask commit:
1. run `python utils/validate_project_structure.py`;
2. for changed project-owned `.gd` files, run formatter/static checks when available;
3. run targeted static inspection only;
4. run `git diff --check`;
5. **do not run GUT/smoke/runtime suites by default**.

Before completing the full implementation task (`Rxx` / `Rxx.x`):
1. run the deterministic checks above;
2. run the relevant GUT regression surface once;
3. run the relevant headless smoke/runtime checks once;
4. record only concise PASS/FAIL evidence;
5. leave visual validation to the user unless explicitly approved.

Exception: a concrete blocking bug may justify one narrow early runtime/GUT run when static evidence is insufficient.

### Runtime validation budget

Token allowance is more important than repeatedly proving the same runtime behavior.

For one complete `Rxx` / `Rxx.x` implementation task, the default budget is:
- **at most one GUT invocation total**;
- **at most one headless smoke/runtime invocation total**;
- **zero rendered/visual invocations** unless the user explicitly approves them.

Normally the GUT and headless smoke/runtime invocations happen at task completion.

If a blocking bug requires an earlier targeted GUT/runtime invocation, that invocation consumes the corresponding task budget. Continue with static/deterministic validation afterward. Any additional GUT/smoke/runtime rerun requires explicit user approval.

Do not create or expand automated physics smoke scenarios merely to judge gameplay feel/tuning such as ramps, steps, uneven terrain, cart handling, camera feel, animation feel, or similar experiential behavior unless the user explicitly requests automated coverage. Those acceptance checks are user-owned.

Do not rerun the same smoke after each small patch. Use the existing failure evidence to batch fixes, then run only within the remaining budget.

Avoid `--editor --import` as routine validation. Use it only when import/scene/resource compilation specifically requires it, and normally only once near task completion.

Runtime logs must be redirected/filtered. Return only the relevant error/assertion/stack or a short PASS summary; never feed the complete noisy Godot/GUT log back into the main context.

If `pre-commit` is installed, `.pre-commit-config.yaml` automates the deterministic structure check, staged diff check, and optional GDScript formatter check. Do not install/upgrade it silently during unrelated work.
