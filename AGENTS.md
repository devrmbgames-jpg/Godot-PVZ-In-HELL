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
- GDScript visibility is naming-based: private members/helpers start with `_`; public members/functions and `@export` fields do not. Signal slots use the `_on_` prefix. Constants use `UPPER_SNAKE_CASE`.
- Every project-owned script has a short responsibility description; public API and authored/exported configuration use useful `##` Godot doc-comments.
- GDScript functions must be visually split into semantic blocks with single blank lines. Simplify dense boolean expressions with named predicates, clear nested `if`s, or private helpers; avoid redundant/misleading casts.
- No magic gameplay constants; use named constants/data.
- Never claim a formatter/test/Godot run passed unless it actually ran.
- Never discard user edits, force-push, rewrite unrelated history, or upgrade dependencies unless requested.
- Never write authored files into `.godot/`.

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

- `Rxx` / `RMxx.x` are implementation task/order IDs.
- `ТЗ xx` labels in `docs/roadmap/` are design-source IDs and do not imply implementation order.
- Use [docs/roadmap/README.md](docs/roadmap/README.md) as the canonical mapping.
- Completed implementation tasks are intentionally absent from `agent_tasks/`; confirm them in `task_history.md` instead of recreating task files.

## Work protocol

For sizable work, maintain `WORK.md`. For interruptible work, keep `CURRENT_WORK.md` as a compact durable checkpoint.

**Create a local git commit after every completed logical stage/milestone and before starting the next stage or separate task.**
- A commit must contain one coherent change.
- Run the narrow relevant validation before committing when possible.
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

Before a milestone commit:
1. run `python utils/validate_project_structure.py`;
2. for changed project-owned `.gd` files, run the formatter checks from `.agents/skills/gdscript-format/SKILL.md` when the CLI is available;
3. run the narrow relevant GUT/smoke/runtime check;
4. run `git diff --check`.

If `pre-commit` is installed, `.pre-commit-config.yaml` automates the deterministic structure check, staged diff check, and optional GDScript formatter check. Do not install/upgrade it silently during unrelated work.
