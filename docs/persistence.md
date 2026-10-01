# Persistence / Night contract

R21 owner: `agent_tasks/roadmap_21_night_persistence_next_day.md` (IN_PROGRESS).

- Main startup reads one `user://autosave.pvzh` before simulation. Tests supply an isolated `autosave_path`. Missing, invalid checksum or incompatible schema starts a fresh scene and reports the reason in debug UI.
- Sleep enters Night with `night_ready=false`. `S_NightSave` runs after phase, wallet/customer settlement and quest outcomes. It clears transient participation, captures the next Morning, writes/flushes a temporary file and atomically renames it into the slot. Failed writes keep Night and retry the same target day; successful writes permit the existing phase System to advance once.
- A successful slot already describes the next Morning. Interruption after file replacement but before the live phase transition therefore resumes that Morning. Progress during the day is committed at Sleep.
- `SaveDataCodec` accepts explicit component fields and record scripts only. Immutable definitions reload by authored resource path; binary variant payloads contain no runtime Objects. Records preserve financial operation IDs, actual customer outcomes separately from declarations, complaints/combat context, late visit IDs, commerce receipts/orders and quest facts.
- Package identity is `package/<package_id>`. Paid pickups use `order/<operation_id>`. Authored entities resolve by scene-relative path; other runtime entities retain their Entity ID. Load validates records before world changes, instantiates missing prefabs, clears all old ownership/storage/cargo bindings, restores component/physical state, then reconstructs Relationships and quest bindings. Disabled entities use World lifecycle APIs.
- Preserve physical transforms, fixed-object snapshots, slot/cart membership and package-local ink. Hand/push/cart driving, dialogue/modal/challenge captures, projectiles, transient hazards and body velocities do not cross Night. Persistent hazards retain their own lifetime/data; fulfilled emitter guards are preserved.
- `OrderDeliveryService` creates one authored physical pickup per paid order when a receiving slot is free. Blocked space leaves the order pending. Existing order identity reconciles an interrupted delivery; fulfilled records remain after pickup/consumption. No second charge occurs.

Foundation checks: codec/store/world GUT and strict main Night/restart/Morning smoke. Morning refusal return and final R21 hardening remain in the owner task.
