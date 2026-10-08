extends RefCounted
## Suppresses gameplay reactions while a prevalidated snapshot overlays defaults and fixes links.
class_name SnapshotRestoreBoundary

#region Transaction reaction boundary
## Starts only after complete preflight; pending old-context commands cannot survive replacement.
static func begin(world: World) -> Dictionary[Observer, bool]:
	var activity: Dictionary[Observer, bool] = {}
	for observer: Observer in world.observers:
		activity[observer] = observer.active
		observer.active = false
		observer.cmd.clear()
	for owner: System in world.systems:
		owner.cmd.clear()
	return activity


## Rebuilds derived bindings before returning observers to their previous activity.
static func finish(world: World, activity: Dictionary[Observer, bool]) -> void:
	for entity: Entity in world.entities:
		if entity.has_component(C_InventoryItem):
			if not entity.relationship_removed.is_connected(InventoryService.ownership_removed):
				entity.relationship_removed.connect(InventoryService.ownership_removed)
		var autosave: C_Autosave = entity.get_component(C_Autosave) as C_Autosave
		if autosave != null:
			autosave.revision += 1
			autosave.work_queued = false
			autosave.preparation = null
			autosave.prepared_snapshot = {}
			autosave.started_night = 0
	_rebuild_monitor_membership(world)
	for observer: Observer in activity:
		observer.active = activity[observer]
#endregion

#region Pinned GECS membership reconstruction
static func _rebuild_monitor_membership(world: World) -> void:
	# GECS v8 suppresses monitor evaluation while inactive. Its public API has no
	# silent reseed operation; this single composition adapter uses the pinned
	# World index/helper to reconstruct membership without publishing MATCH events.
	# No addon mutation or gameplay replay is involved.
	var entries_by_observer: Dictionary = world.get("_obs_entries_by_observer") as Dictionary
	for entries_value: Variant in entries_by_observer.values():
		var entries: Array = entries_value as Array
		for entry: Dictionary in entries:
			if bool(entry.get("is_monitor", false)):
				(entry.membership as Dictionary).clear()
				world.call("_seed_monitor_membership", entry, false)
#endregion
