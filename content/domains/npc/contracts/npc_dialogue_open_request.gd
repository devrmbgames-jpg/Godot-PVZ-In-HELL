extends RefCounted
## Синхронный запрос уличного UI с identity witness физического NPC.
class_name NpcDialogueOpenRequest

## Канал запроса существующей панели.
const EVENT: StringName = &"npc_dialogue_open_request"
## Слабый endpoint игрока на границе World callback.
var actor_reference: WeakRef
## Runtime identity игрока до callback.
var actor_id: String
## Тот же профиль тела, который разрешил разговор.
var identity: C_NpcIdentity
## Результат единственного синхронного UI consumer.
var opened: bool = false

#region Создание запроса
## Сохраняет проверяемые endpoints без владения UI или игроком.
func _init(actor: Entity, captured_identity: C_NpcIdentity) -> void:
	actor_reference = weakref(actor)
	actor_id = actor.id
	identity = captured_identity
#endregion
