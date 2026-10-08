extends RefCounted
## Синхронное закрытие native панели до дальнейшего gameplay действия с NPC.
class_name NpcDialogueCloseRequest

## Канал закрытия представления; gameplay связи отдельно завершает NPC owner.
const EVENT: StringName = &"npc_dialogue_close_request"
