extends Resource
## Durable registration identity; inactive records retain history without reserving their number.
class_name PackageRegistrationRecord

@export var package_id: String = ""
@export var day_index: int = 0
@export var number: int = 0
@export var definition: DEF_Package = null
## Only active warehouse records reserve a base number across days.
@export var active: bool = true
