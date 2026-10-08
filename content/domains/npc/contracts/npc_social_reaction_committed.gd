extends RefCounted
## Подтверждённая социальная реакция NPC без знания его необязательных клиентских ролей.
class_name NpcSocialReactionCommitted

## Канал факта после изменения боя, восприятия и представления.
const EVENT: StringName = &"npc_social_reaction_committed"
## Зафиксированная реакция, выбранная памятью личности.
var reaction: NpcMemory.Reaction = NpcMemory.Reaction.TALK
## Наличие боевой цели после применения реакции.
var combat_active: bool = false

#region Создание факта
## Копирует результат без удержания изменяемого NPC или его роли.
func _init(committed_reaction: NpcMemory.Reaction = NpcMemory.Reaction.TALK, has_combat_target: bool = false) -> void:
	reaction = committed_reaction
	combat_active = has_combat_target
#endregion
