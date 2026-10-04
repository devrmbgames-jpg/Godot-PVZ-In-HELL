extends Observer
## Передаёт уже принятый результат урона личным свидетелям через NpcSocialService.
class_name O_NpcIncident

#region Наблюдение результатов урона
## Слушает принятые результаты урона Entity с Health.
func query() -> QueryBuilder:
	return q.with_all([C_Health]).on_event(DamageResult.EVENT)

## Планирует социальную обработку результата после CommandBuffer; здоровье не изменяет.
func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result != null:
		cmd.add_custom(NpcSocialService.observe_damage.bind(result))
#endregion
