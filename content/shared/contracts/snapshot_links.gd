extends RefCounted
## Closed durable link vocabulary shared by snapshot adapters and preflight rules.
class_name SnapshotLinks

## Inventory item points to its authoritative owner.
const OWNED: String = "owned"
## Physical body points to its occupied physical slot.
const STORED: String = "stored"
## Physical cargo points to its transport cart with a retained local pose.
const CARGO: String = "cargo"
