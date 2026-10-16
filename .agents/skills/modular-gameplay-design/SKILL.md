---
name: modular-gameplay-design
description: Required when planning, implementing or extending substantial gameplay features, or when a local feature starts requiring changes across unrelated subsystems. Defines composable mechanics, narrow integration contracts and complete behavior packages without speculative frameworks.
---

# Modular gameplay design

Compose large features from small, complete mechanics with explicit responsibility
boundaries. Adding or changing one mechanic should require the smallest justified
change to neighboring systems. Splitting a monolith into more files is not modularity.

Use this before substantial feature planning/implementation and when scope grows.
For a small local fix, apply the principle without a new planning exercise, task file
or architecture document. Do not reopen accepted work solely to adopt this skill.

## 1. Define the mechanic, not the file list

In the current session plan or existing owning task, briefly identify:
- the observable behavior and concrete completion condition;
- the authoritative owner of each state, including existing shared state;
- inputs, outputs, cancellation/lifetime rules and necessary dependencies;
- touched owners/contracts and why each must change, plus explicit exclusions;
- the focused checks and integration scenarios that demonstrate completion.

Reuse existing task fields; no mandatory new report, queue or duplicate plan.
Autonomy means bounded responsibilities and testable contracts, not zero dependencies,
a separate ECS world, a new subsystem per action or a requirement to run in isolation.
Keep tightly coupled invariants/atomic operations together rather than splitting them
into independently committed half-transactions just to make packages smaller.

## 2. Integrate through narrow existing contracts

Reuse the existing movement, physics, damage, inventory, economy, delivery, dialogue
and persistence owners. Do not create feature-local copies of those systems.
Follow AGENTS.md: Components/aggregates own data, Relationships own live bindings,
Systems own scheduled behavior, Observers own reactions and Services explicit operations.
Definitions remain authoring data; BT and UI do not become competing state owners.

Separate behavior selection, action execution and consequences. A reaction chooser
selects an outcome; it does not also move a body, settle an order and pay a wallet.
Use explicit typed domain operations and results/events at the appropriate boundary.
Commands that require an immediate atomic result remain synchronous; do not impose
an event bus, asynchronous pipeline or distributed transaction on a local operation.
Preserve ordering, callback revalidation and once-only commit guarantees when needed.

A consumer should not write another owner's mutable internals. Extend the provider's
smallest necessary contract and update affected real consumers. Do not introduce
circular dependencies between features or re-export the provider's entire internals.
Use authored data for variants when the existing contract fits; do not build a generic
plugin framework, interface hierarchy or future API without a current real consumer.
These are responsibility boundaries, not a mandate for one new class per boundary.

## 3. Deliver complete behavior packages

Split large scope into coherent behavior results, not horizontal phases such as
"all Components -> all Services -> all Systems -> integrate everything at the end".
Each package delivers a usable/testable increment on its required shared foundation.
Include its native authoring, lifetime cleanup, cancellation and save/restore guarantees
where applicable. A mock-only pass does not close required real integration acceptance.
Final integration covers cross-mechanic interactions; it does not defer basic correctness.

Map every original requirement and edge case to a package or an explicit existing
shared contract. Do not shrink acceptance, delete requirements or defer mandatory work
without owner authorization. Avoid one task/review per method, file or technical layer.
Size packages by behavioral cohesion and risk, not an arbitrary file/domain count.

Dependencies name specific implemented/verified provider contracts, not full-task DONE
when only an unrelated owner QA gate remains. Implement the producer before dependent
work; do not claim a planned API exists or implement a second owner to bypass it.
For each package, identify persistent versus transient fields before implementation;
update codec/preflight/fixtures together using the actual schema version. Do not keep
incompatible data under one version or reserve future schema numbers from old plans.

## 4. Reassess scope before spreading changes

If a local feature requires broad changes to neighboring systems, pause expansion,
not the whole autonomous run. Check whether the spread comes from an overly broad
implementation, a truly missing shared contract or an explicitly requested migration.
Record the concrete dependency and smallest necessary provider change in the same plan.

When the shared contract is genuinely missing, isolate a bounded preparatory stage
with its own acceptance and first real consumer in the same coherent milestone.
Do not build an abstract foundation with no working consumer. Keep unrelated cleanup,
renaming and opportunistic rewrites outside the feature. A new requirement/owner decision
is a real scope gate, not permission to silently widen the task.

An explicit systemic migration, such as replacing the physical body of all live NPCs,
can legitimately touch many systems. Use [refactoring](../refactoring/SKILL.md), name
the migrated callers and preserve behavior outside scope. Do not leave permanent dual
old/new runtime paths in order to claim smaller packages; temporary adapters follow
the refactoring skill's completion and external-compatibility rules.

## 5. Example and completion check

Parcel reactions compose these responsibilities:
offer detection -> reaction selection -> existing hold/throw/fire operation ->
existing incident/order accounting. This is not a demand for four new subsystems.
An additional throw reaction should reuse the real physical hold/impact contracts;
it should not require a new movement controller, wallet or delivery ledger.
Theft can require explicit incident/save changes without changing the lawful recipient.

Before closing a package, check:
- Does it deliver its promised behavior, including required lifetime/save guarantees?
- Is each state owned once, and are neighboring changes necessary and explicit?
- Could the next similar variant use the same narrow boundary, without rewriting
  unrelated systems? Assess the design; do not implement that hypothetical variant.
- Are affected consumer regressions covered and all remaining requirements assigned?

Use [validation-workflow](../validation-workflow/SKILL.md) for proportional actual checks
and [review-orchestration](../review-orchestration/SKILL.md) for substantial milestones;
this skill adds no extra full-suite or per-file review gate.
Follow [task-lifecycle](../task-lifecycle/SKILL.md): after an accepted package, continue
autonomously to the next permitted package/task. A blocked provider stops dependent
work, not independent work. Preserve owner deferrals, rendered-QA restrictions and
honest NOT_RUN/REVIEW_PENDING/OWNER_QA states. Decomposition is not a new approval loop.
