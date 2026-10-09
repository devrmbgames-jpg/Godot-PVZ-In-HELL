extends RefCounted
## Одноразовый запрос торговли; native UI владеет созданием и modal lifetime панели.
class_name CommercePanelOpenRequest

## Канал запроса к global UI adapter.
const EVENT: StringName = &"commerce_panel_open_requested"
## Lifetime witness участника, передаваемый через World callback.
var actor_reference: WeakRef
## Native identity участника текущего запроса.
var actor_id: String
## Точная роль торговца на момент принятия interaction action.
var trader: C_Trader
## Результат открытия, записанный native UI owner.
var opened: bool = false

#region Request snapshot
func _init(actor: Entity, source: Entity) -> void:
	actor_reference = weakref(actor)
	actor_id = actor.id
	trader = source.get_component(C_Trader) as C_Trader
#endregion
