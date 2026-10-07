---
name: refactoring
description: >
  Required for explicit broad refactoring, architecture migration, subsystem
  decomposition, or repository-wide cleanup. Defines completeness, migration,
  compatibility, validation, and no-half-refactor rules.
---

# Refactoring

Refactoring is behavior-preserving architecture work unless the user explicitly requests a behavior change.

## Full-refactor rule

When the task explicitly says to refactor a subsystem, architecture, or declared scope, finish that refactor to the target architecture inside the declared scope.

Do not stop at a compatibility-shaped halfway state such as:
- old and new execution paths both remaining active;
- a new abstraction wrapping the old architecture without removing it;
- deprecated aliases/wrappers kept only because deleting them requires updating callers;
- files moved while ownership stays unchanged;
- a large Service renamed without separating its real responsibilities;
- a vertical-domain migration that leaves the same gameplay ownership split between old horizontal roots and the new domain;
- new validation added while known violations inside the completed scope remain silently allowlisted.

Temporary adapters are allowed only as an implementation step inside the same durable milestone. Remove them before marking that milestone DONE unless an external compatibility contract genuinely requires them.

If a blocker prevents completing the declared scope, record the task as BLOCKED/partial. Do not call a half-migration complete.

"Refactor fully" does not mean changing unrelated features. Scope remains deliberate: complete the chosen architecture migration, preserve unrelated behavior and user edits, and do not expand into neighboring product changes without architectural necessity.

## Required completion work

A completed refactor normally includes, where applicable:
- migrate all callers in scope;
- update scenes/resources/paths and stable contracts intentionally;
- remove dead wrappers, aliases, duplicate state, and obsolete code;
- update tests and validation;
- update durable architecture docs and agent rules when the contract changed;
- run the narrowest checks that can prove the migration and a broader acceptance check at the milestone boundary.

## Architecture migration

Prefer a single target model over permanent dual models.

For ECS work:
- Components/Relationships remain authoritative state;
- Systems own scheduled behavior;
- Observers own discrete reactions;
- Services own explicit synchronous domain operations;
- Rules/Calculations/Geometry/Solvers own reusable algorithms without hidden scheduling;
- UI remains Godot glue, not ECS;
- Traits/Templates are authoring/compiler inputs, not runtime schedulers or mutable gameplay state.

For vertical-domain work:
- move ownership, not only files;
- domain-to-domain dependencies must use typed commands/events, stable domain APIs, or explicit shared contracts;
- use canonical role directories and pass the domain-structure validator;
- the final strict validation must not rely on legacy horizontal gameplay roots.

## Review question

Before marking a refactor complete, ask:

> If a new developer only saw the target architecture, would they still need to understand the old architecture to modify this subsystem safely?

If yes, the migration is probably incomplete.
