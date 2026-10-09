extends Observer
## Однократно создаёт авторские эффекты истощения отдельно от арифметики здоровья.
class_name O_DepletionEffects


#region Принятие однократного эффекта
## Подписывается на результат здоровья сущностей с авторским планом эффектов.
func query() -> QueryBuilder:
	return q.with_all([C_HealthDepletionEffects]).on_event(DamageResult.EVENT)


## Фиксирует защиту повтора до callback и ставит создание эффектов в CommandBuffer.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
		return
	if not is_instance_valid(entity):
		return

	var effects: C_HealthDepletionEffects = entity.get_component(C_HealthDepletionEffects)
	if effects == null or effects.committed:
		return

	effects.committed = true

	var health_depletion_effects: HealthDepletionEvent = HealthDepletionEvent.new()
	health_depletion_effects.cause = result
	health_depletion_effects.world_pose = result.world_pose
	health_depletion_effects.vfx = effects.vfx
	health_depletion_effects.sfx = effects.sfx
	var entries: Array[DEF_DepletionSpawn] = effects.spawns.duplicate()
	cmd.add_custom(_dispatch.bind(entries, health_depletion_effects))


#endregion

#region Создание игровых сцен и уведомление
func _dispatch(
	entries: Array[DEF_DepletionSpawn],
	health_depletion_effects: HealthDepletionEvent,
) -> void:
	if not is_instance_valid(_world):
		return

	for entry: DEF_DepletionSpawn in entries:
		if entry == null or entry.scene == null:
			continue

		var spawned: Node = entry.scene.instantiate()
		_world.add_child(spawned)
		var spatial: Node3D = spawned as Node3D
		if spatial != null:
			spatial.global_transform = health_depletion_effects.world_pose * entry.offset
		var entity: Entity = spawned as Entity
		if entity != null:
			var context: EntitySpawnContext = EntityCompositionService.context_for(entity, _world,
				entity.id if not entity.id.is_empty() else GECSIO.uuid())
			if not EntityCompositionService.try_register(context, false):
				spawned.free()
				continue

	# Уведомление остаётся пригодным после удаления исходной цели доменной реакцией.
	_world.emit_event(HealthDepletionEvent.EVENT, null, health_depletion_effects)

#endregion
