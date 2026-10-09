extends RefCounted
## Проверка необязательной роли перед уличным разговором; NPC не импортирует её состояние.
class_name NpcConversationPermissionRequest

## Канал синхронного role permission query.
const EVENT: StringName = &"npc_conversation_permission_request"
## Владелец активной роли может запретить разговор; NPC без роли сохраняет обычную доступность.
var allowed: bool = true
