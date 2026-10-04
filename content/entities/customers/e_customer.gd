@tool
extends E_NpcCharacter
## Дополняет представление NPC анимациями обслуживания; физический цикл остаётся в базовом классе.
class_name E_Customer

## Необязательная стационарная анимация осмотра; при отсутствии используется idle.
@export var inspection_animation: StringName = &""
## Необязательная стационарная анимация получения заказа.
@export var receiving_animation: StringName = &""
## Необязательная стационарная анимация разговора.
@export var dialogue_animation: StringName = &""


#region Представление обслуживания
func _stationary_animation() -> StringName:
	var agent: C_CustomerAgent = get_component(C_CustomerAgent) as C_CustomerAgent
	var candidate: StringName = &""
	if agent != null:
		match agent.phase:
			C_CustomerAgent.Phase.INSPECTING, C_CustomerAgent.Phase.OPTIONAL_FITTING: candidate = inspection_animation
			C_CustomerAgent.Phase.RECEIVING: candidate = receiving_animation
			C_CustomerAgent.Phase.DIALOGUE: candidate = dialogue_animation
	return candidate if animation_player != null and animation_player.has_animation(candidate) else idle_animation


## Обновляет необязательную Label3D Message; факты визита не изменяет.
func show_message(message: String) -> void:
	var label: Label3D = get_node_or_null("Message") as Label3D
	if label != null:
		label.text = message

#endregion
