---
name: save-systems
description: >
  Use for persistent game-state serialization, stable IDs, save schema design,
  migrations, autosave/checkpoints, crash-safe writes, and restoring GECS/domain
  state across sessions.
---

# Save Systems

A save is a **versioned snapshot of authoritative domain data**, not a serialized SceneTree.

## Project identity rules

- Persistent identity uses explicit stable IDs.
- Never persist NodePath, instance ID, RID, live Entity/Object reference, or transient LimboAI/Blackboard reference as durable identity.
- Relationships with durable meaning serialize their stable endpoint/domain IDs and are reconstructed after entities exist.
- Derived/cache Components should normally be rebuilt from authoritative data instead of persisted.
- Godot/Jolt runtime transforms are saved only when the owning gameplay contract actually requires pose persistence.

## Schema

Every durable save format must have a schema version from its first shipped version.

Load flow:
1. parse;
2. check version;
3. migrate older schema step-by-step;
4. validate required data/ranges/IDs;
5. construct authoritative entities/domain records;
6. restore relationships/references in a second phase;
7. rebuild derived caches/presentation.

Do not silently guess how a newer save should be interpreted by older code.

## Snapshot consistency

Capture at an explicit safe boundary or from a coherent authoritative snapshot.

- Avoid saving halfway through a multi-step mutation where related systems disagree.
- Autosave at meaningful stable boundaries and throttle it.
- Keep autosave separate from deliberate/manual save data when one should not overwrite the other.
- Expensive serialization/I/O may be deferred, but do not read live mutable SceneTree state unsafely from worker threads.

## Storage safety

- Runtime saves belong under `user://`, never authored `res://`.
- Write to a temporary/new file, flush/close it, then replace the active save using a recoverable strategy appropriate to the platform.
- Keep a last-known-good backup when corruption/power-loss recovery matters.
- Validate before replacing the current in-memory state.
- Treat local save contents as untrusted input: malformed values must fail safely rather than create invalid entities/state.

## Migration discipline

A migration transforms data from version N to N+1 and should be deterministic and testable without gameplay.

Preserve old migrations after release. Do not make current gameplay code contain scattered legacy-version conditionals when a load-time migration can normalize the data once.

## Validation

For persistence changes, prefer tests that:
- round-trip representative data;
- load at least the previous schema version;
- reject malformed/newer unsupported data cleanly;
- verify stable relationships reconstruct by ID;
- fully quit/reload when a real persistence path must be proven.

Source inspiration: adapted selectively from `save-systems` in `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0); project stable-ID and GECS contracts override generic examples.
