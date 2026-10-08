extends RefCounted
## Validates retained receiving recipes offline before any live body, queue or ownership changes.
class_name ReceivingSnapshotRules

#region Pending recipe preflight
## Verifies every retained key/scene pair and the authored zone's selected delivery definition.
static func valid(receiving: C_Receiving, actor: Entity) -> bool:
	var zone: E_ReceivingZone = actor as E_ReceivingZone
	for batch: ReceivingBatch in receiving.pending:
		if batch.day_index < 1 or batch.next_package < 0:
			return false
		if batch.source not in [ReceivingBatch.Source.BASE_SUPPLY, ReceivingBatch.Source.PENDING_ORDER]:
			return false
		if batch.next_package > batch.package_keys.size():
			return false
		if batch.package_keys.size() != batch.package_scenes.size():
			return false
		for index: int in batch.package_keys.size():
			var key: String = batch.package_keys[index]
			var path: String = batch.package_scenes[index]
			if key.is_empty() or not path.begins_with("res://content/entities/packages/"):
				return false
			if path.simplify_path() != path or not ResourceLoader.exists(path, "PackedScene"):
				return false
			var packed: PackedScene = load(path) as PackedScene
			var instance: Node = packed.instantiate()
			var parcel: E_Package = instance as E_Package
			var compatible: bool = parcel != null and instance is RigidBody3D
			if compatible and zone != null:
				var definition: DEF_Package = null
				if zone.supply != null:
					for candidate: DEF_Package in zone.supply.packages:
						if String(candidate.key) == key:
							definition = candidate
				compatible = definition != null and path in definition.scene_variants
			instance.free()
			if not compatible:
				return false
	return true
#endregion
