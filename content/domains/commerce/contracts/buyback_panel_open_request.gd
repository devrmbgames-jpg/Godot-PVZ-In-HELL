extends RefCounted
## Запрос UI хранит lifetime witnesses, не подтверждает и не резервирует продажу.
class_name BuybackPanelOpenRequest

## Канал global UI adapter.
const EVENT: StringName = &"buyback_panel_open_requested"
## Игрок, инициировавший действие.
var actor_reference: WeakRef
## Identity игрока защищает от повторного использования queued запроса.
var actor_id: String
## Точный контейнер на момент действия.
var container_reference: WeakRef
## Точная incarnation прайса контейнера.
var state: C_Buyback
## UI observer пишет результат создания панели.
var opened: bool = false


#region Detached request
func _init(actor: Entity, container: E_BuybackContainer) -> void:
	actor_reference = weakref(actor)
	actor_id = actor.id
	container_reference = weakref(container)
	state = container.get_component(C_Buyback) as C_Buyback
#endregion
