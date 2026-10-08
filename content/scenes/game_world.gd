extends World
## Registers a level's authored ECS graph only after explicit placed identity validation succeeds.
class_name GameWorld

var _identity_issues: Array[String] = []
var _startup_activity: Dictionary[Observer, bool] = {}
var _restoring: bool = false

#region Validated world registration
func _ready() -> void:
	_identity_issues = PlacedIdentityRules.compile_for(get_parent())
	if not _identity_issues.is_empty():
		return
	var level: Node = get_parent()
	var candidate: Dictionary = GameSessionService.startup_snapshot(level,
		String(level.get("autosave_path")))
	_restoring = not candidate.is_empty() and WorldSnapshotService.can_restore(candidate, level)
	if _restoring:
		for child: Node in get_node(system_nodes_root).find_children("*", "Observer"):
			var observer: Observer = child as Observer
			_startup_activity[observer] = observer.active
			observer.active = false
	super._ready()


## Reports rejected authored identity without partially registering actors or starting simulation.
func initialization_failed() -> bool:
	return not _identity_issues.is_empty()


## Returns a copy of actionable authoring diagnostics for the composition owner.
func identity_issues() -> Array[String]:
	return _identity_issues.duplicate()


## Reports the passive startup transaction to the level composition owner.
func restoring_startup() -> bool:
	return _restoring


## Adds composition observers without enabling gameplay before restored fixup completes.
func add_startup_observer(observer: Observer) -> void:
	if _restoring:
		_startup_activity[observer] = observer.active
		observer.active = false
	add_observer(observer)


## Publishes readiness after all state, links and derived bindings have been reconstructed.
func finish_startup() -> void:
	for observer: Observer in _startup_activity:
		observer.active = _startup_activity[observer]
	_startup_activity.clear()
	_restoring = false
#endregion
