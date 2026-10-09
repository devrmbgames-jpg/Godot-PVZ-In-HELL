---
name: gdscript-style
description: Required when writing or editing project-owned GDScript (.gd); covers typing, naming, clarity and style checks.
---

# GDScript style — required implementation contract

Use before editing project-owned GDScript. For routine code changes this short checklist is sufficient. For non-obvious readability or reference-lifetime tradeoffs read [detailed examples](references/extended-guidance.md); do not preload them for simple edits.

## Readability and structure

- Write for a human maintaining this code months later. Prefer explicit intent, descriptive symbols, typed intermediate results, linear flow and clear stages over clever one-liners.
- Do not change role-aware `class_name` prefixes `C_`, `S_`, `O_`, `R_`, `E_`, `DEF_`, `ET_`, `UI_` to satisfy generic PascalCase lint. Normal classes use PascalCase; functions, parameters, variables and signals use snake_case; constants use CONSTANT_CASE.
- Avoid names shadowing script members, inherited Godot properties/methods or important enclosing symbols. Behavior/glue/UI members are private by default, and `@onready` fields are private unless an external API contract explicitly requires otherwise.
- Each script has a short `##` description. Document every `@export` field, public mutable API/data field and signal; document public methods whose purpose is not self-evident. Describe ownership, units and constraints instead of repeating the name.
- Group related methods in named `#region ...` / `#endregion` chapters; not one region per method. Separate logical phases of nontrivial functions with one blank line; add a short intent comment to complex, non-obvious multi-step blocks. Avoid mechanical empty lines or comments restating code.
- Avoid unexplained gameplay/tuning literals; use constants or authored values where the name adds meaning. Do not invent arbitrary maximum function lengths or split clear linear code into meaningless helpers.

## Types, ECS and lifetime

- Project-owned GDScript uses static typing. Declare a concrete type when inference crosses Variant, dictionaries, dynamic `get()`, physics query payloads, broad Object/Node interfaces, or dynamically loaded resources. Use typed containers for stable element types; avoid ambiguous `:=`.
- Required Entities/Components in a synchronous query or service call are invariants, not nullable guesses. Do not add blanket `null` or `is_instance_valid()` guards that hide invalid ownership. Optional lookups may be checked; delayed/stored/deferred/queued references must be revalidated at their genuine lifetime boundary.
- Debug `assert(...)` can expose mandatory-state violations but must be side-effect-free and cannot substitute for runtime recovery. Use the GECS-safe lifecycle path for structural destruction. See [GECS usage](../gecs-v8/SKILL.md) for subsystem-specific contracts.

## Scope and verification

- Apply new style to new or materially edited project-owned code; do not mass-rewrite unrelated legacy files or third-party addons. For explicitly broad migrations follow [refactoring](../refactoring/SKILL.md) and finish their declared scope.
- GDQuest formatter/linter and repo configuration are mechanical authorities, except the intentional `class-name` rule: local wrapper disables only that rule and validates role-aware names separately. Do not suppress unrelated warnings or rename architecture roles.
- Prefer line lengths around 100 characters while retaining readable names. Run `python utils/check_gdscript_format.py --changed` near the coherent commit; missing formatter is NOT_RUN (exit 2), never PASS. See [validation-workflow](../validation-workflow/SKILL.md) for parser and milestone checks.

Review question: can a developer understand purpose, control flow, types, important ownership and non-obvious work without reconstructing the author's reasoning?
