extends RefCounted
## Проверенное предложение создания мебели; при отказе оплаты вызывающий освобождает entity.
class_name PreparedFurniture

## Созданный, ещё не зарегистрированный экземпляр; передать commit или освободить.
var entity: Entity = null
## Будущий родитель мебели в сцене.
var parent: Node3D = null
## Проверенная мировая поза для однократного размещения.
var world_pose: Transform3D = Transform3D.IDENTITY

## Transient identity/World inputs captured before any payment or delivery fulfillment.
var spawn_context: EntitySpawnContext = null
## Validated fresh recipes; consumed in the same synchronous transaction, never cached at runtime.
var build_plan: EntityBuildPlan = null
