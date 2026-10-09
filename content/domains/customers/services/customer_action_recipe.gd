extends RefCounted
## Устанавливает immutable action definitions клиентской роли в существующую capability recipe тела.
class_name CustomerActionRecipe

#region Рецепт взаимодействия
## Создаёт отдельный начальный набор действий, сохраняя authored IDs и приоритеты.
static func create() -> C_InteractionActionSet:
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	_install_missing(actions)
	return actions


## Добавляет отсутствующие определения при первом получении роли; после установки они только читаются.
static func install(body: Entity) -> void:
	var actions: C_InteractionActionSet = body.get_component(C_InteractionActionSet) as C_InteractionActionSet
	if actions == null:
		body.add_component(create())
	else:
		_install_missing(actions)


static func _install_missing(actions: C_InteractionActionSet) -> void:
	var has_dialogue: bool = false
	var has_handoff: bool = false
	for action: DEF_InteractionAction in actions.actions:
		has_dialogue = has_dialogue or action is DEF_CustomerAction
		has_handoff = has_handoff or action is DEF_CustomerHandoffAction

	# Preserve the original action order ahead of native street/trader definitions.
	if not has_handoff:
		var handoff: DEF_CustomerHandoffAction = DEF_CustomerHandoffAction.new()
		handoff.action_id = &"customer_handoff"
		handoff.caption = "Передать посылку"
		handoff.priority = 10
		handoff.allow_interact_fallback = false
		actions.actions.push_front(handoff)
	if not has_dialogue:
		var dialogue: DEF_CustomerAction = DEF_CustomerAction.new()
		dialogue.action_id = &"customer_request"
		dialogue.caption = "Поговорить"
		actions.actions.push_front(dialogue)
#endregion
