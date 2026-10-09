extends RefCounted
## Синхронный запрос native UI после проверки клиентской роли; сохраняет только witness и слабого игрока.
class_name CustomerDialogueOpenRequest

## Канал запроса существующей панели.
const EVENT: StringName = &"customer_dialogue_open_request"
## Слабый endpoint игрока на границе World callback.
var actor_reference: WeakRef
## Runtime identity игрока, проверяемая перед открытием UI.
var actor_id: String
## Та же клиентская роль, которая разрешила запрос.
var agent: C_CustomerAgent
## Результат единственного синхронного UI consumer.
var opened: bool = false

#region Создание запроса
## Сохраняет identity/witness без новой модели разговора или владения игроком.
func _init(actor: Entity, captured_agent: C_CustomerAgent) -> void:
	actor_reference = weakref(actor)
	actor_id = actor.id
	agent = captured_agent
#endregion
