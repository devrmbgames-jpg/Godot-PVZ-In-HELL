extends RefCounted
## Receiving batch lifecycle and one-package delivery transaction.
class_name ReceivingDeliveryService

const BLOCKED_RETRY_SECONDS: float = 0.25


static func deliver_one(
	zone: E_ReceivingZone,
	receiving: C_Receiving,
	day_index: int,
) -> void:
	if not is_instance_valid(zone) or zone.supply == null:
		return
	if receiving.last_started_day < day_index:
		var batch: ReceivingBatch = ReceivingBatch.new()
		batch.day_index = day_index
		receiving.pending.append(batch)
		receiving.last_started_day = day_index
	if receiving.pending.is_empty():
		return
	if receiving.last_spawn_tick == Engine.get_physics_frames():
		return

	var batch: ReceivingBatch = receiving.pending[0]
	if batch.next_package >= zone.supply.packages.size():
		receiving.pending.pop_front()
		receiving.blocked = false
		return

	var definition: DEF_Package = zone.supply.packages[batch.next_package]
	var package_id: String = "%s:%d:%s" % [zone.supply.key, batch.day_index, definition.key]
	if ReceivingPackageFactory.exists(package_id):
		_advance(receiving, batch)
		return

	var parcel: E_Package = ReceivingPackageFactory.create(
		zone,
		definition,
		package_id,
		batch.day_index,
		batch.next_package,
	)
	if parcel == null:
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return
	if not ReceivingPackageFactory.try_place(zone, parcel):
		parcel.free()
		receiving.blocked = true
		receiving.retry_remaining = BLOCKED_RETRY_SECONDS
		return

	receiving.last_spawn_tick = Engine.get_physics_frames()
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	if identity != null:
		identity.delivery_day = batch.day_index
		identity.supply_key = zone.supply.key
	_advance(receiving, batch)


static func _advance(receiving: C_Receiving, batch: ReceivingBatch) -> void:
	batch.next_package += 1
	receiving.delivered_counts[batch.day_index] = batch.next_package
	receiving.blocked = false
