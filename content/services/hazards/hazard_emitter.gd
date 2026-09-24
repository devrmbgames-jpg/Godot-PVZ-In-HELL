extends RefCounted
## Reusable activation seam for any C_HazardEmitter owner; no Package-specific effect logic.
class_name HazardEmitter


## Guards one-shot producers before submitting; repeatable emitters receive distinct request IDs.
static func activate(
	origin: Entity,
	instigator: Entity = null,
	stable_origin_id: String = "",
) -> bool:
	if not EntityAvailability.contains(origin, ECS.world):
		return false

	var emitter: C_HazardEmitter = origin.get_component(C_HazardEmitter) as C_HazardEmitter
	var spatial: Node3D = origin as Node as Node3D
	if emitter == null or spatial == null or emitter.definition == null:
		return false

	if emitter.one_shot and emitter.fired:
		return false

	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.origin_id = stable_origin_id if not stable_origin_id.is_empty() else origin.id
	request.request_id = "%s:%d" % [request.origin_id, emitter.sequence + 1]
	request.origin = origin
	request.instigator = instigator
	request.definition = emitter.definition
	request.world_pose = spatial.global_transform
	request.ownership = emitter.definition.ownership
	request.owner_loss = emitter.definition.owner_loss

	var was_fired: bool = emitter.fired
	emitter.fired = true
	emitter.sequence += 1
	if not HazardSpawnService.submit(request):
		emitter.fired = was_fired
		emitter.sequence -= 1
		return false

	return true
