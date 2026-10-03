extends Observer
## Forwards committed health results to personal witnesses without changing Health.
class_name O_NpcIncident

#region Damage observation
func query() -> QueryBuilder:
	return q.with_all([C_Health]).on_event(DamageResult.EVENT)

func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result != null:
		cmd.add_custom(NpcSocialService.observe_damage.bind(result))
#endregion
