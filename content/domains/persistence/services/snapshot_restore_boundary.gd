extends RefCounted
## Suppresses gameplay reactions while a prevalidated snapshot overlays defaults and fixes links.
class_name SnapshotRestoreBoundary


#region Transaction reaction boundary
## Starts only after complete preflight; pending old-context commands cannot survive replacement.
static func begin(world: World) -> Dictionary[Observer, bool]:
	world.emit_event(WorldReconstructionStarted.EVENT, null, WorldReconstructionStarted.new())
	var activity: Dictionary[Observer, bool] = ObserverReactionBoundary.suspend(world.observers)
	for observer: Observer in world.observers:
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
			autosave.prepared_snapshot = { }
			autosave.started_night = 0
	ObserverReactionBoundary.resume(world, activity)
#endregion
