extends System
## Owns stable_seconds progression; anchor/unfix remain explicit physical transactions.
class_name S_AnchorStability

#region Scheduled rest accumulation
## Selects enabled authored anchor targets.
func query() -> QueryBuilder:
	return q.enabled().with_all([C_Anchorable])


## Commits transient rest time from actual body motion and live relationship participation.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if not is_finite(delta):
		return

	for target: Entity in entities:
		var config: C_Anchorable = target.get_component(C_Anchorable) as C_Anchorable
		_accumulate_rest(target, config, delta)


func _accumulate_rest(target: Entity, config: C_Anchorable, delta: float) -> void:
	if (
		delta <= 0.0 or not GrabService.entity_available(target)
		or AnchoringService.state(target) != null or AnchoringService.controlled(target)
	):
		config.stable_seconds = 0.0
		return

	var body: RigidBody3D = GrabService.physical_body(target)
	if body == null or body.freeze:
		config.stable_seconds = 0.0
		return
	if not AnchoringRules.within_motion_limits(body, config):
		config.stable_seconds = 0.0
		return

	config.stable_seconds += delta


#endregion
