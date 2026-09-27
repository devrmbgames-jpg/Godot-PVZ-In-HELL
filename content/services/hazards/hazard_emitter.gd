extends RefCounted
## Reusable activation seam for autonomous hazard scenes; no Package-specific effect logic.
class_name HazardEmitter


static func emit_scene(
	origin: Entity,
	scene: PackedScene,
	request_id: String,
	instigator: Entity = null,
	stable_origin_id: String = "",
	stable_instigator_id: String = "",
) -> bool:
	if not EntityAvailability.contains(origin, ECS.world) or scene == null:
		return false
	var spatial: Node3D = origin as Node as Node3D
	if spatial == null:
		return false

	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.origin_id = stable_origin_id if not stable_origin_id.is_empty() else origin.id
	request.request_id = request_id
	request.origin = origin
	request.instigator = instigator
	request.instigator_id = stable_instigator_id
	request.scene = scene
	request.world_pose = spatial.global_transform
	return HazardSpawnService.submit(request)


static func activate(
	origin: Entity,
	instigator: Entity = null,
	stable_origin_id: String = "",
	stable_instigator_id: String = "",
) -> bool:
	if not EntityAvailability.contains(origin, ECS.world):
		return false

	var emitter: C_HazardEmitter = origin.get_component(C_HazardEmitter) as C_HazardEmitter
	if emitter == null or emitter.hazard_scene == null:
		return false
	if emitter.one_shot and emitter.fired:
		return false

	var origin_id: String = stable_origin_id if not stable_origin_id.is_empty() else origin.id
	var request_id: String = "%s:%d" % [origin_id, emitter.sequence + 1]
	var was_fired: bool = emitter.fired
	emitter.fired = true
	emitter.sequence += 1
	if not emit_scene(
		origin,
		emitter.hazard_scene,
		request_id,
		instigator,
		origin_id,
		stable_instigator_id,
	):
		emitter.fired = was_fired
		emitter.sequence -= 1
		return false
	return true
