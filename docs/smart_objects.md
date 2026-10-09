# Smart Objects

The interaction domain owns Smart Object transactions. Physical actors stay native editable
scenes. `C_SmartObject.definition` contains immutable authored capabilities; live occupancy
is exclusively `actor --R_SmartObjectReservation--> object`. Markers present service positions.
There is no slot Entity, global executor registry or authoritative reverse occupancy cache.

## Author a variant

1. Instantiate an existing physical prefab, such as `package_return_point.tscn`.
2. Give each service position a native `Marker3D`. In `DEF_SmartObject.slots`, set its stable
   `slot_id` and local marker path. Slot IDs are scoped to that object.
3. Add `DEF_SmartAffordance` data: operation ID, declared slot, existing typed executor and
   required actor Component scripts. Executors implement pure `is_available` and an actual
   `complete` result. They do not reserve slots, yield, or recursively call this adapter.
4. Set the definition on `ET_SmartObject` inside the object's flat Template. The common compiler
   materializes `C_SmartObject` and one `C_InteractionActionSet`; remove an old independent
   action-set provider during migration. The native scene still owns its physical structure.
5. Validate Scene Composition using the task42 Inspector, or run detached preview headlessly.
   The same Trait provider rejects missing/duplicate slot IDs, missing markers, absent executor,
   recursive Smart Object adapter, input timing, and invalid required Component scripts.

`def_smart_package_return.tres` reuses `DEF_PackageReturnAction`. Its input ID, channel, caption
and fallback policy are preserved by the generic adapter. `package_return_point_wall.tscn`
changes only native presentation/marker data and uses the same definition and executor.

## Player, AI, quests and dialogue

All callers use `SmartObjectService.is_available(actor, object, affordance_id)` for discovery
and `submit(operation, actor, object, affordance_id, token)` for mutation. The player adapter
uses this API through the existing action resolver/input owner; it introduces no raw input loop.
LimboAI tasks, quest handlers and dialogue mutations call the same service. Store a receipt
for observation and its token for the operation, never a copied occupancy flag in Blackboard/UI.

| Operation | Receipt after commit | Ownership |
| --- | --- | --- |
| `ACQUIRE` | `ACQUIRED` with a token, or `REJECTED` | Keeps one live reservation |
| `EXECUTE` | `SUCCEEDED` only if the executor succeeds, otherwise `REJECTED` | Requires exact token; retires that binding |
| `CANCEL` | `CANCELLED`, or `REJECTED` for stale/conflicting token | Retires precisely the captured binding |
| `USE` | `SUCCEEDED` or `REJECTED` | Acquires, executes and retires in one operation |

A returned `PENDING` means queued, never successful. `O_SmartObject` is the only request
handler. Its default `PER_CALLBACK` buffer normally commits before submission returns;
MANUAL buffers commit at `World.flush_command_buffers()`. Eligibility and exclusivity are
checked at commit, with no yield between the check and relation publication. A synchronous
executor callback cannot execute/cancel an already executing reservation a second time.
Clients must observe the receipt rather than equate dispatch or a boolean enqueue with success.

## Lifetime and save/load

Tokens contain World, object and materialized Component incarnations plus a monotonically
increasing acquisition sequence. They are transient; the closed save codec does not save
Smart Object reservation links, sequence or receipts. Reusing stable actor/object IDs cannot
make a removed/recreated object's token valid.

Death, disable, World removal, required actor capability loss, capability replacement and
participant tree exit retire participation. Derived engine callbacks disconnect when the
exact relationship is removed. Slot/eligibility loss at execution rejects and releases that
reservation. Failed executors also release the slot, without reporting success.

After saved-state preflight accepts an in-place load, `SnapshotRestoreBoundary.begin` emits
`WorldReconstructionStarted` before suspending reactions/clearing buffers. The Smart Object
owner rejects pending receipts and retires transient relationships even if World and placed
Nodes are retained. A request captured from a replaced World is rejected at commit as well.
Late callbacks cannot remove a fresh binding: retirement checks exact Relationship identity.

## Verification

`test_smart_objects.gd` covers queued contention, commit-time eligibility, executor failure,
stale tokens, Node/Component/World replacement, same-World restore, death/disable/capability
loss, tree-exit callback cleanup, exclusive ownership at execute/cancel and shared schema
validation on both native variants. `test_package_return.gd` executes the actual package
return through real RayCast eligibility on both variants and checks parcel/ledger/settlement
and reservation state. Snapshot/startup regressions and authored interaction smoke cover
the affected restoration and native World composition boundaries.
