extends RefCounted
## Обломки зарегистрированы; O_PackageDestruction удаляет исходную коробку после emit_event.
class_name PackageDebrisSpawnedEvent

## Канал World с записью завершённого создания обломков.
const EVENT: StringName = &"package_debris_spawned"

## Созданная живая сущность обломков.
var debris: Entity = null
## Стабильный ID исходной посылки, доступный после удаления коробки.
var package_id: String = ""
## Авторское определение исходной посылки.
var definition: DEF_Package = null
## Причина уничтожения, если оно произошло через урон.
var cause: DamageResult = null
## Мировое положение коробки в момент уничтожения.
var world_pose: Transform3D = Transform3D.IDENTITY
## Пустая оболочка не наследует опасность уничтоженного содержимого.
var contents_released: bool = false
## A catalog payload replaces legacy contents hazards with its captured native effect.
var catalog_order: bool = false
## Actual catalog rupture effect captured before package/debris publication can change lifetime.
var catalog_rupture_hazard: PackedScene = null
