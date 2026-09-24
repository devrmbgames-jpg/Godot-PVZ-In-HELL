extends RefCounted
## Snapshots generic spawn requests onto the World's Observer event channel.
class_name HazardSpawnService


## Submission is independent of origin lifetime; no System lookup or HP mutation occurs here.
static func submit(request: HazardSpawnRequest) -> bool:
	if request == null or not is_instance_valid(ECS.world):
		return false

	if request.request_id.is_empty() or request.origin_id.is_empty():
		return false

	if request.definition == null or request.definition.scene == null:
		return false

	if not request.world_pose.is_finite():
		return false

	if (
		not is_finite(request.definition.lifetime_seconds)
		or request.definition.lifetime_seconds <= 0.0
	):
		return false

	var snapshot: HazardSpawnRequest = HazardSpawnRequest.new()
	snapshot.request_id = request.request_id
	snapshot.origin_id = request.origin_id
	snapshot.instigator_id = request.instigator_id
	snapshot.definition = request.definition
	snapshot.world_pose = request.world_pose
	snapshot.origin = request.origin if is_instance_valid(request.origin) else null
	snapshot.instigator = request.instigator if is_instance_valid(request.instigator) else null
	snapshot.ownership = request.ownership
	snapshot.owner_loss = request.owner_loss
	snapshot.damage_blocked = request.damage_blocked
	if snapshot.origin != null and snapshot.origin.has_component(C_NoDamage):
		snapshot.damage_blocked = true

	if snapshot.instigator_id.is_empty() and snapshot.instigator != null:
		snapshot.instigator_id = snapshot.instigator.id

	ECS.world.emit_event(HazardSpawnRequest.EVENT, null, snapshot)
	return true
