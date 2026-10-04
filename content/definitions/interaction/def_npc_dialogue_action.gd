extends DEF_InteractionAction
## Открывает уличный разговор; игровые последствия применяют сервисы контекста.
class_name DEF_NpcDialogueAction

#region Взаимодействие
## Проверяет возможность явного разговора с жителем, включая ожидающего в очереди.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return NpcDialogueService.can_start(actor, source as E_DistrictNpc)

## Запрашивает один разговор через сервис диалогов NPC.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	NpcDialogueService.start(actor, source as E_DistrictNpc)
#endregion
