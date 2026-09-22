extends Component
## Warehouse registration data; allocation and lifecycle behavior belong to the service.
class_name C_PackageLedger

@export var records: Array[PackageRegistrationRecord] = []
## Keep the most recent departure visible after its number returns to the pool.
@export var last_departed_package_id: String = ""
