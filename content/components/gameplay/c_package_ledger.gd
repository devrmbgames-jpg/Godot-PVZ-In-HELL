extends Component
## Warehouse registration data; allocation and lifecycle behavior belong to the service.
class_name C_PackageLedger

@export var records: Array[PackageRegistrationRecord] = []
## Day-local allocator for hidden package history IDs. Persist with the ledger.
@export var history_sequence_day: int = 0
@export var next_history_number: int = 1
## Keep the most recent departure visible after its number returns to the pool.
@export var last_departed_package_id: String = ""
