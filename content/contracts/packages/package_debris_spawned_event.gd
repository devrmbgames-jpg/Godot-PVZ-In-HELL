extends RefCounted
## Emitted after a destroyed Package has been replaced by its authored debris Entity.
class_name PackageDebrisSpawnedEvent

const EVENT: StringName = &"package_debris_spawned"

var debris: Entity = null
var package_id: String = ""
var definition: DEF_Package = null
var cause: DamageResult = null
var world_pose: Transform3D = Transform3D.IDENTITY
## Пустая оболочка не наследует опасность уничтоженного содержимого.
var contents_released: bool = false
