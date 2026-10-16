extends RefCounted
## Validates retained receiving recipes offline before any live body, queue or ownership changes.
class_name ReceivingSnapshotRules


#region Pending recipe preflight
## Verifies every retained key/scene pair and the authored zone's selected delivery definition.
## Receives decoded state; loads allowed assets and instantiates/frees detached parcel probes.
## Supply-profile matching applies when actor is E_ReceivingZone; no World/queue mutation occurs.
static func valid(receiving: C_Receiving, actor: Entity) -> bool:
	var receipt_ids: Dictionary[String, bool] = { }
	for receipt: TruckCargoReceipt in receiving.cargo_receipts:
		if (
			receipt == null or receipt.batch_id.is_empty()
			or receipt.day_index < 1 or receipt.day_index > receiving.last_started_day
			or receipt.kind < TruckCargoReceipt.Kind.RETURN
			or receipt.kind > TruckCargoReceipt.Kind.DISPOSAL
			or receipt.amount < 0 or receipt.amount > WalletService.MAX_AMOUNT
			or (receipt.amount > 0 and receipt.kind != TruckCargoReceipt.Kind.SALE)
			or (receipt.settled and not receipt.removed)
		):
			return false
		if receipt.entity_id.is_empty() == receipt.raw_actor_id.is_empty():
			return false
		if not receipt.raw_actor_id.is_empty():
			if (
				not RawPhysicsActorService.valid_id(receipt.raw_actor_id)
				or receipt.kind != TruckCargoReceipt.Kind.DISPOSAL or receipt.amount != 0
			):
				return false
		var target_id: String = (
			"entity/" + receipt.entity_id
			if not receipt.entity_id.is_empty()
			else "raw/" + receipt.raw_actor_id
		)
		var receipt_id: String = receipt.batch_id + "/" + target_id
		if receipt_ids.has(receipt_id):
			return false
		receipt_ids[receipt_id] = true
		if (receiving.dispatched_batch_id == receipt.batch_id and not receipt.settled):
			return false
	var zone: E_ReceivingZone = actor as E_ReceivingZone
	for batch: ReceivingBatch in receiving.pending:
		if batch.day_index < 1 or batch.next_package < 0:
			return false
		if (
			batch.source
			not in [ReceivingBatch.Source.BASE_SUPPLY, ReceivingBatch.Source.PENDING_ORDER]
		):
			return false
		if batch.next_package > batch.package_keys.size():
			return false
		if batch.package_keys.size() != batch.package_scenes.size():
			return false
		if batch.package_keys.size() != batch.order_item_paths.size():
			return false
		if (
			batch.package_keys.size() != batch.order_quantities.size()
			or batch.package_keys.size() != batch.order_packing_paths.size()
		):
			return false
		for index: int in batch.package_keys.size():
			var key: String = batch.package_keys[index]
			var path: String = batch.package_scenes[index]
			var item_path: String = batch.order_item_paths[index]
			var packing_path: String = batch.order_packing_paths[index]
			var item: DEF_InventoryItem = null
			var packing: DEF_PackagePacking = null
			if not item_path.is_empty():
				if (
					not GameplayResourcePaths.is_definition_path(item_path)
					or item_path.simplify_path() != item_path
					or not ResourceLoader.exists(item_path)
					or not GameplayResourcePaths.is_definition_path(packing_path)
					or packing_path.simplify_path() != packing_path
					or not ResourceLoader.exists(packing_path)
				):
					return false
				item = load(item_path) as DEF_InventoryItem
				packing = load(packing_path) as DEF_PackagePacking
				if not PackageOrderRules.is_orderable(item):
					return false
			elif not packing_path.is_empty():
				return false
			if not PackageShipmentRules.valid(item, batch.order_quantities[index], packing, path):
				return false
			if key.is_empty() or not path.begins_with("res://content/domains/packages/entities/"):
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
				compatible = definition != null
				if compatible:
					compatible = (
						definition.unpack_scene != null if item != null
						else path in definition.scene_variants
					)
			instance.free()
			if not compatible:
				return false
	return true
#endregion
