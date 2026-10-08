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



#endregion

#region Рецепт клиентской роли
## Добавляет начальную роль только при отсутствии явного authored recipe override.
func define_components() -> Array[Component]:
	var recipe: Array[Component] = []
	var authored_agent: bool = false
	var authored_actions: bool = false
	for component: Component in component_resources:
		authored_agent = authored_agent or component is C_CustomerAgent
		authored_actions = authored_actions or component is C_InteractionActionSet

	if not authored_agent:
		recipe.append(C_CustomerAgent.new())
	if not authored_actions:
		recipe.append(CustomerActionRecipe.create())
	return recipe
#endregion
