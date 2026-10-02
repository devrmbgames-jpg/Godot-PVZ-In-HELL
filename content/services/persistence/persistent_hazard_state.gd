extends RefCounted
## Primitive reference keys; live attribution/follow is rebuilt after all entities exist.
class_name PersistentHazardState


static func capture(entity: Entity, root: Node) -> Dictionary:
	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	if hazard == null:
		return {}
	var data: Dictionary = {"origin": _key(hazard.origin, root), "instigator": _key(hazard.instigator, root)}
	var binding: Relationship = HazardFollowService.binding(entity)
	if binding != null:
		var follow: R_HazardFollow = binding.relation as R_HazardFollow
		data.follow = {"target": _key(binding.target as Entity, root), "offset": follow.local_offset, "on_loss": follow.on_loss}
	return data


static func valid(data: Dictionary, records: Dictionary[String, Dictionary]) -> bool:
	for field: String in ["origin", "instigator"]:
		if not data.get(field) is String or (not String(data[field]).is_empty() and not records.has(String(data[field]))):
			return false
	if data.has("follow"):
		if not data.follow is Dictionary:
			return false
		var follow: Dictionary = data.follow as Dictionary
		if not follow.get("target") is String or not records.has(String(follow.target)) or not follow.get("offset") is Transform3D or not (follow.offset as Transform3D).is_finite() or follow.get("on_loss") not in [DEF_Hazard.OwnerLoss.Detach, DEF_Hazard.OwnerLoss.Despawn]:
			return false
	return true


static func restore(data: Dictionary, entity: Entity, entities: Dictionary[String, Entity]) -> void:
	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	if hazard == null:
		return
	hazard.origin = entities.get(String(data.get("origin", ""))) as Entity
	hazard.instigator = entities.get(String(data.get("instigator", ""))) as Entity
	var owner: Entity = null
	var follow: R_HazardFollow = null
	if data.has("follow"):
		var saved: Dictionary = data.follow as Dictionary
		follow = R_HazardFollow.new()
		owner = entities[String(saved.target)]
		follow.local_offset = saved.offset as Transform3D
		follow.on_loss = int(saved.on_loss) as DEF_Hazard.OwnerLoss
	HazardFollowService.replace(entity, owner, follow)
	# Rebuild native collision/visual geometry without replaying a resolved explosion.
	if entity.has_component(C_ToxicArea) or entity.has_component(C_Explosion):
		var result: HazardSpawnResult = HazardSpawnResult.new()
		result.hazard = entity
		result.request_id = hazard.request_id
		result.origin_id = hazard.origin_id
		result.restored = true
		ECS.world.emit_event(HazardSpawnResult.EVENT, entity, result)


static func reset_missing_owners() -> void:
	for entity: Entity in ECS.world.entities.duplicate():
		if not is_instance_valid(entity):
			continue
		var lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
		if lifetime != null and lifetime.owner_loss_pending:
			HazardLifecycle.retire(entity, ECS.world)
			continue
		var binding: Relationship = HazardFollowService.binding(entity)
		if binding == null or EntityAvailability.contains(binding.target, ECS.world):
			continue
		var follow: R_HazardFollow = binding.relation as R_HazardFollow
		if follow.on_loss == DEF_Hazard.OwnerLoss.Despawn:
			HazardLifecycle.retire(entity, ECS.world)
		else:
			entity.remove_relationship(binding)


static func _key(entity: Entity, root: Node) -> String:
	if not EntityAvailability.contains(entity, ECS.world):
		return ""
	var key: String = WorldSnapshotService.key_for(entity, root)
	# Customers/projectiles are reset before capture, so only persistent live refs remain.
	return key
