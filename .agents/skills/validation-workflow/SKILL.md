---
name: validation-workflow
description: Use when verifying code/scene changes or closing implementation milestones; selects parser, formatter, validators, GUT and smoke checks.
---

# Scoped change validation

Choose the cheapest check capable of falsifying the changed behavior, then a broader
acceptance surface at a coherent milestone. Do not trade correctness for fewer calls.
Docs/prompt/config-only changes need relevant text/link/schema checks, not gameplay/GUT.
Non-visual local Godot/disposable tests are allowed; rendered gameplay/visual QA needs
explicit task-specific approval. Preserve already recorded approval without expanding it.

## Engine checks, independent of MCP

After a coherent .gd/.tscn/.tres batch, verify the changed surface with actual Godot.
On Windows use utils/godot_agent.ps1 or the matching VS Code task:
- -Action ParseChanged, or -Action ParseFiles -Paths ...: actual load/parser.
- -Action GUT -TestPath res://tests/gut/<focused_test>.gd: native focused tests.
- -Action Import / OfflineScript -ScriptPath res://...: only after closing the live
  project editor; offline scripts extend SceneTree/MainLoop, not EditorScript.
- utils/run_smoke.ps1 -Name <focused_smoke>: bounded relevant headless smoke.

Missing executable/runner means NOT_RUN, never static PASS as substitute. MCP failure
alone does not waive engine checks. Problems lists/formatter/filesystem scans do not
prove runtime acceptance. Prefer MCP script_patch/script_create diagnostics for live
editor edits and resolve relevant reload warnings, but do not repeatedly validate
identical code with MCP and CLI merely to produce additional green labels.
The runner must not launch rendered gameplay, overwrite open scenes or force-restart
an editor simply to satisfy a check. Editor ownership rules remain mandatory.

## GDScript and static gates

Before a coherent project .gd commit run python utils/check_gdscript_format.py --changed;
it checks changed lines/new files, not mass-formatting legacy code. Missing GDQuest
formatter exit 2 is NOT_RUN. For committed scope use --base <revision>; --strict only
for declared full-file/style migration. Validate changed scripts near batch completion.

For substantial code/scene changes run python utils/validate_agent_changes.py,
python -B utils/validate_architecture.py --strict and python utils/validate_project_structure.py,
plus structure/persistence-specific checks whose contracts changed.
validate_agent_changes.py --staged checks the index; --report-only is not accepted PASS.
Static gates supplement, never replace, architecture review and native regressions.

## Coherent validation packages

A local fix gets its reproducer and affected guarantees. A completed large gameplay
package normally gets focused native GUT and one suitable headless smoke/runtime check,
unless its acceptance defines a more specific surface. Use gut-testing for test design.
Do not rerun the entire suite/export after each small edit. Native parser and runtime
cover different guarantees; avoid redundant launches without dropping required gates.
Record the tested SHA/scope and commands. Reuse evidence only for unchanged relevant
inputs; changes to a provider invalidate affected consumer checks, not every past test.
Group tests only with demonstrated state isolation and individual results. Do not
assume multi-file GUT support or speedup; the runner task must implement/measure it first.

Review substantial committed checkpoints on immutable full SHAs via review-orchestration;
resolve accepted P0/P1/P2 before that milestone is complete. Fix review is targeted to
finding/fix/affected consumers, not another repository-wide investigation. Unavailable
review is REVIEW_PENDING/NOT_RUN; self-review is NON_INDEPENDENT.
Runnable .export/ Windows QA builds belong to completed large gameplay milestones,
not documentation/config changes or every internal step.

## Evidence, shutdown diagnostics and unavailable gates

Report command, scope and actual PASS/FAIL/NOT_RUN with raw failure logs preserved.
Never claim filesystem writes, headless assertions or a successful formatter prove
runtime correctness or visual feel. An unavailable mandatory gate stays open;
[task lifecycle](../task-lifecycle/SKILL.md) permits independent backlog work meanwhile.

For genuine memory/retention questions read
[memory/lifetime diagnostics](references/memory-lifetime.md), not on every routine edit.
Native test result and shutdown diagnostic classification are distinct. Known shutdown-only
GDScript/GDScriptNativeClass/Resource/StringName/RID retention on the pinned engine follows
owner policy, not a new investigation or automatic acceptance of arbitrary stderr.
Preserve wrapper FAIL when reporting the raw command and separately document the narrowly
justified engine classification; do not relabel an unmodified runner as fixed.
Unknown/mixed diagnostics, nonzero exit, missing completion, runtime growth/live Nodes,
use-after-free/double-free still block affected work. Never blanket-ignore ERROR or RID.
The [runner task](../../tasks/godot_validation_result_classification.md) covers actual
classification changes/tests. Until it is implemented, do not claim a new CLI mode exists.
