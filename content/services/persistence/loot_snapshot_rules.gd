extends RefCounted
## Проверяет ID и закрытые пути ожидающего дропа до изменения живого мира.
class_name LootSnapshotRules

const MAX_PENDING: int = 4096

#region Предварительная проверка очереди
## Единственная очередь принадлежит сессии; ожидающий ID не имеет уже созданного физического экземпляра.
static func valid(records: Dictionary[String, Dictionary], components: Dictionary[String, Dictionary]) -> bool:
	var queue_count: int = 0
	for key: String in components:
		var types: Dictionary = components[key]
		if not types.has(C_LootDrops):
			continue
		queue_count += 1
		var queue: C_LootDrops = types[C_LootDrops] as C_LootDrops
		if queue_count > 1 or not types.has(C_DayCycle) or not _valid_policy(queue.placement) or queue.pending.size() > MAX_PENDING:
			return false

		var ids: Dictionary[String, bool] = {}
		for batch_id: String in queue.committed_batches:
			if batch_id.is_empty() or not queue.committed_batches[batch_id]:
				return false
		for item: PendingLootDrop in queue.pending:
			if item == null or not queue.committed_batches.has(item.batch_id) or item.drop_id.is_empty() or not item.drop_id.begins_with("loot/" + item.batch_id + "/") or ids.has(item.drop_id) or records.has(item.drop_id):
				return false
			if not item.origin.is_finite() or not item.anchor.is_finite() or not item.velocity.is_finite() or not _valid_scene(item.scene_path, "res://content/entities/"):
				return false
			if not item.opening_hazard_path.is_empty() and not _valid_scene(item.opening_hazard_path, "res://content/entities/hazards/"):
				return false
			ids[item.drop_id] = true
	return true

static func _valid_scene(path: String, prefix: String) -> bool:
	return path.begins_with(prefix) and path.simplify_path() == path and ResourceLoader.exists(path, "PackedScene")

static func _valid_policy(policy: DEF_ItemPlacement) -> bool:
	if policy == null or policy.resource_path.is_empty() or policy.offsets.is_empty() or policy.offsets.size() > DEF_ItemPlacement.MAX_CANDIDATES:
		return false
	for offset: Vector3 in policy.offsets:
		if not offset.is_finite():
			return false
	return policy.obstacle_mask > 0 and policy.support_mask > 0 and policy.retry_seconds >= 0.25 and policy.initial_budget in range(1, 17) and policy.retry_budget in range(1, 17) and policy.clearance > policy.margin and policy.probe_depth > 0.0
#endregion
