extends RefCounted
## Lifetime-safe намерение открыть native подтверждение у самого ящика, без диалога с NPC.
class_name CraftingPanelOpenRequest

## Канал глобального native UI adapter.
const EVENT: StringName = &"crafting_panel_open_requested"
## Слабая ссылка на инициатора и его identity witness.
var actor_reference: WeakRef
## Стабильная identity игрока в момент действия.
var actor_id: String
## Точная native точка и incarnation профиля в момент действия.
var container_reference: WeakRef
## Incarnation authored компонента, которую обязан перечитать queued handler.
var state: C_Crafting
## Результат открытия пишет UI observer, не подтверждение расхода.
var opened: bool = false


#region Lifetime witnesses
func _init(actor: Entity, container: E_CraftingContainer) -> void:
	actor_reference = weakref(actor)
	actor_id = actor.id
	container_reference = weakref(container)
	state = container.get_component(C_Crafting) as C_Crafting
#endregion
