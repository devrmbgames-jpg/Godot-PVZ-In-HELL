---
name: dialogue-manager-v4.1
description: >
  Use for Nathan Hoad Dialogue Manager v4.1.0 syntax, DialogueResource/DialogueLine/
  DialogueResponse APIs, cues, conditions, mutations, tags, extra_game_states,
  custom dialogue UI, and addon-specific debugging in this project.
---

# Dialogue Manager v4.1.0

The project vendors Nathan Hoad's Dialogue Manager under `addons/dialogue_manager/`.
`plugin.cfg` is pinned to **4.1.0**. Treat the addon as read-only unless an addon upgrade/fix is explicit.

Local checked-out addon code is the runtime/API authority. When external reference is needed, use upstream `nathanhoad/godot_dialogue_manager` tag `v4.1.0` (commit `a719088aea342572f29b5559fd8726896c9519b2`), not current `main`.

This skill owns addon syntax/API. For project dialogue semantics, Customer outcomes, response intent, idempotency, and authority boundaries, also use `.agents/skills/dialogue-systems/SKILL.md`.

## Project integration

The project does **not** use Dialogue Manager's example balloon as the Customer dialogue owner.

Current path:
- `CustomerDialogueService` selects/loads the `.dialogue` resource and cue.
- `CustomerDialogueContext` is the typed game-state adapter.
- `CustomerDialoguePanel` owns presentation and modal input.
- dialogue is advanced with `await resource.get_next_dialogue_line(next_id, [{"ctx": context}])`.
- response routing uses `DialogueResponse.next_id`.
- semantic response tags are read from `DialogueResponse.tags` and mapped through `CustomerDialogueIntent`.
- gameplay mutations exposed to dialogue go through narrow `ctx.*` methods into owning services.

Do not replace this with `show_dialogue_balloon()`, `Actionable3D`, global autoload shortcuts, or `DialogueStateContext` merely because those are supported by the addon.

## State and authority

Dialogue Manager is stateless; project gameplay remains authoritative.

Prefer the current explicit context:
```gdscript
await resource.get_next_dialogue_line(cue, [{"ctx": context}])
```

In `.dialogue`:
```text
if ctx.some_condition()
    Клиент: ...
$> ctx.some_action()
```

Rules:
- expose the smallest typed adapter needed by the dialogue;
- do not expose broad Entity/world/service objects when a narrow context method is sufficient;
- dialogue expressions may read state, but durable mutations should call an owning project service through the context;
- do not store authoritative gameplay state in dialogue locals, line objects, or UI;
- preserve idempotency when a branch/mutation can be revisited.

Dialogue Manager can resolve globals, scene contexts, classes, and arbitrary members, but broader access is not a reason to bypass project boundaries.

## Dialogue syntax used in this project

### Cues and jumps

```text
~ direct
Клиент: Здравствуйте.
=> deny_start

~ deny_start
...
=> END
```

- `~ cue_name` defines a cue.
- `=> cue_name` jumps.
- `=> END` ends the current flow.
- `=> END!` force-ends chained jump/return flows.
- `=>< cue_name` jumps and later returns.

Prefer stable semantic cue names. Before starting from a computed cue, verify `resource.cues.has(cue)`.

### Responses

```text
Клиент: Почему?
- Честный ответ [#hon] => honest
- Соврать [#lie] => lie
```

Runtime:
- `DialogueLine.responses` contains `DialogueResponse` objects.
- skip or disable responses with `response.is_allowed == false` according to UI contract.
- advance using `response.next_id`.
- tags belong to authored routing/metadata; presentation prefixes must not mutate `response.text` or `response.tags`.

### Conditions

```text
if ctx.has_registered_number()
    Клиент: ...
elif ctx.some_other_condition()
    Клиент: ...
else
    Клиент: ...
```

Conditional response:
```text
- Вариант [if ctx.can_do_it() /] => branch
```

Keep conditions observational where practical. Avoid hiding domain mutations inside methods that look like predicates.

### Mutations

Dialogue Manager 4.1.0 documentation prefers `$>`:

```text
$> ctx.commit_denial()
```

`do` and `set` remain supported in 4.1.0 but are documented upstream as deprecated syntax. For new or substantially edited dialogue, prefer `$>`. Do **not** mass-rewrite existing authored files solely for style unless migration is requested.

Inline mutations execute while text is being typed and can alter timing/lifecycle semantics. Avoid them for core gameplay transitions unless the feature explicitly depends on typewriter timing.

## Runtime API

Preferred project-level API:
```gdscript
var line: DialogueLine = await resource.get_next_dialogue_line(
    cue,
    [{"ctx": context}],
)
```

Important:
- `get_next_dialogue_line()` must be awaited;
- it traverses non-printable flow and executes mutations until a printable `DialogueLine` or end;
- `null` means dialogue ended;
- pass the previous `DialogueLine.next_id` or `DialogueResponse.next_id` to continue;
- default mutation behaviour is `DMConstants.MutationBehaviour.Wait`; keep it unless there is a concrete reason to change async mutation semantics.

Useful runtime types:
- `DialogueResource`: compiled dialogue resource/cues/lines.
- `DialogueLine`: `id`, `next_id`, `character`, `text`, `tags`, `responses`, `concurrent_lines`.
- `DialogueResponse`: `next_id`, `is_allowed`, `text`, `tags`, condition metadata.
- `DialogueLine.has_tag()` / `get_tag_value()` and equivalent response helpers for authored metadata.

Do not depend on internal compiled `resource.lines` structure for feature logic unless there is no public API alternative.

## Resource lifecycle trap in v4.1.0

In this pinned integration, `DialogueManager.get_line()` writes a runtime `resource` reference into shared compiled line dictionaries. That forms:

`DialogueResource -> lines -> DialogueResource`

The project deliberately clears those references with:
```gdscript
DialogueResourceLifecycle.release_runtime_references(resource)
```

Therefore:
- Customer dialogue session close must release runtime references.
- If an awaited line returns after the panel/session was already closed, release the captured resource before discarding the line.
- Do not remove this cleanup as "unnecessary"; it is covered by `tests/gut/test_customer_dialogue.gd`.
- Do not mutate or deep-copy authored `resource.lines` casually to solve this; use the existing lifecycle helper.

## Custom UI

`CustomerDialoguePanel` is the project-owned renderer/input surface.

Preserve:
- `InteractionControlFocus.Priority.MODAL` acquisition/release;
- mouse-mode restore on close;
- focus of the first response/continue control;
- context validity checks while the panel is open;
- authored response text/tags remaining unchanged;
- cleanup if the actor/customer/session becomes invalid during an await.

If typewriter effects are added, consider the addon's `DialogueLabel` rather than reimplementing its BBCode waits/speed/inline-mutation behavior, but only if it fits the project panel contract. Do not replace the panel wholesale.

## Authoring and localization

- `.dialogue` is an imported Godot resource; keep `*.dialogue` included in exports.
- Tags use `[#tag]` or `[#name=value]`.
- Static translation IDs use `[ID:SOME_KEY]` when stable line IDs are needed.
- `##` before dialogue lines can become translator notes in gettext export.
- Visible/localized text must not be used as a gameplay routing key; use cues/tags/stable IDs.

## Validation

For Dialogue Manager work use the cheapest relevant checks:

1. For `.gd` integration changes, run Godot parser/diagnostics as required by project policy.
2. For `.dialogue` edits, compile/import with the installed Dialogue Manager/Godot editor; do not assume plain-text appearance proves syntax validity.
3. For Customer dialogue logic, prefer `tests/gut/test_customer_dialogue.gd`.
4. Verify changed cues exist and affected responses expose the expected `next_id`, `is_allowed`, and tags.
5. Check side-effecting branches for repeated-entry/idempotency.
6. Do not launch broad gameplay just to validate dialogue syntax.

## Context discipline

Do not preload the whole addon. Start from the project dialogue/context/panel being changed. Inspect only the exact addon symbol or upstream v4.1.0 doc section needed when behavior is uncertain.

Avoid editing `addons/dialogue_manager/` for project-specific behavior. Keep adapters, lifecycle workarounds, UI, and domain logic under project-owned `content/` unless the task explicitly targets the dependency itself.
