extends Observer
## Дискретная проекция принятой/выданной партии и кампанийной надписи на native сцену.
class_name O_Crafting


#region Реакции представления
func sub_observers() -> Array[Array]:
	return [
		[q.with_all([C_Crafting]).on_match(), _changed, true],
		[q.on_event(CraftingService.EVENT), _changed],
	]


func _changed(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	cmd.add_custom(_show.bind(weakref(entity), entity.get_component(C_Crafting) as C_Crafting))


func _show(reference: WeakRef, state: C_Crafting) -> void:
	var container: E_CraftingContainer = reference.get_ref() as E_CraftingContainer
	if (
		ECS.world != _world or not EntityAvailability.contains(container, _world)
		or container.get_component(C_Crafting) != state
	):
		return
	var lines: PackedStringArray = [state.profile.display_name]
	var active: CraftingBatch = CraftingQueries.active(container)
	if active == null:
		lines.append("Положите материалы и подтвердите передачу всего содержимого")
	else:
		lines.append("Принято. Готово утром №%d" % active.ready_day)
		var issued: int = 0
		for output: CraftingOutput in active.outputs:
			if output.emitted:
				issued += 1
		if issued > 0:
			lines.append("Выдано %d из %d. Заберите всю партию" % [issued, active.outputs.size()])
		lines.append("Неиспользованные материалы — подарок")
	var hint: String = ""
	for batch: CraftingBatch in CraftingQueries.batches():
		if (
			batch.profile.npc_id == state.profile.npc_id and batch.first_failure and batch.completed
		):
			var ingredients: PackedStringArray = []
			for ingredient: CraftingIngredient in batch.profile.hint_recipe.ingredients:
				ingredients.append(
					"%s ×%d" % [ingredient.definition.display_name, ingredient.quantity],
				)
			hint = "Спасибо за подарок. Принеси " + ", ".join(ingredients) + "."
			break
	container.show_state("\n".join(lines), hint)
#endregion
