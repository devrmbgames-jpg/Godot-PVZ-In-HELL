@tool
extends Entity
## Авторский физический слот; начальную mount-связь проверяет общий compiler до регистрации.
class_name E_PhysicalSlot

#region Авторские физические опоры
## Авторская точка, к которой крепится физический предмет.
@export var anchor: Node3D = null
## RemoteTransform3D, передающий положение закреплённому и временно замороженному предмету.
@export var driver: RemoteTransform3D = null

#endregion
