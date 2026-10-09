extends RefCounted
## Suspends Observer reactions and restores derived membership without replaying effects.
class_name ObserverReactionBoundary


## Short-lived capture preserves native initial event matching while deferring gameplay callbacks.
class RegistrationScope extends RefCounted:
	var _world: World
	var _actor: Entity
	var _activity: Dictionary[Observer, bool]
	var _notifications: Array[Dictionary] = []
	var _closed: bool = false


	#region Initial native event capture
	func _init(world: World, actor: Entity) -> void:
		_world = world
		_actor = actor
		_activity = ObserverReactionBoundary.suspend(world.observers)
		_world.component_added.connect(_capture_component)
		_world.relationship_added.connect(_capture_relationship)


	func _capture_component(actor: Entity, component: Resource) -> void:
		if actor == _actor:
			_capture(Observer.Event.ADDED, component)


	func _capture_relationship(actor: Entity, relationship: Relationship) -> void:
		if actor == _actor:
			_capture(Observer.Event.RELATIONSHIP_ADDED, relationship)


	func _capture(event: Observer.Event, payload: Variant) -> void:
		# Read the pinned dispatcher index when the native event occurs.
		# Re-matching after ready would duplicate multi-Component on_added reactions.
		var by_event: Dictionary = _world.get("_obs_entries_by_event") as Dictionary
		var entries: Array = by_event.get(event, []) as Array
		for entry: Dictionary in entries.duplicate():
			var observer: Observer = entry.observer as Observer
			if not _activity.get(observer, false) or observer.paused:
				continue
			if event == Observer.Event.ADDED:
				var component: Resource = payload as Resource
				var watched: Array = entry.get("watched_paths", []) as Array
				if not watched.is_empty() and not watched.has(component.get_script().resource_path):
					continue
			else:
				var query: QueryBuilder = entry.query as QueryBuilder
				var relation_types: Array = query.get("_observer_rel_add_types") as Array
				if (
					not relation_types.is_empty()
					and not bool(
						_world.call("_relationship_matches_types", payload, relation_types)
					)
				):
					continue
			if bool(_world.call("_observer_entry_entity_matches", entry, _actor)):
				_notifications.append({ "entry": entry, "event": event, "payload": payload })
	#endregion


	#region Accepted ready publication
	## Delivers captured initial events once after fields and bindings are ready.
	func finish() -> void:
		assert(not _closed, "A native registration notification scope closes once")
		_closed = true
		_world.component_added.disconnect(_capture_component)
		_world.relationship_added.disconnect(_capture_relationship)
		for observer: Observer in _activity:
			observer.active = _activity[observer]

		# Captured callbacks cross a lifetime boundary: an earlier callback may retire its Observer.
		for notification: Dictionary in _notifications:
			var entry: Dictionary = notification.entry as Dictionary
			var observer: Observer = entry.observer as Observer
			if is_instance_valid(observer) and observer.active and not observer.paused:
				_world.call(
					"_invoke_entry",
					entry,
					notification.event,
					_actor,
					notification.payload,
				)
		_notifications.clear()
		_world.call("_evaluate_monitors_for_entity", _actor, [])
		_activity.clear()
	#endregion


#region Runtime registration notifications
## Holds gameplay reactions while preserving native subscription matching and callback order.
static func begin_registration(world: World, actor: Entity) -> RegistrationScope:
	return RegistrationScope.new(world, actor)
#endregion


#region Synchronous construction reaction scope
## Captures activity for an explicit Observer set and prevents partial-construction reactions.
static func suspend(subjects: Array[Observer]) -> Dictionary[Observer, bool]:
	var activity: Dictionary[Observer, bool] = { }
	for observer: Observer in subjects:
		activity[observer] = observer.active
		observer.active = false
	return activity


## Seeds current native membership silently before restoring each Observer's captured activity.
static func resume(world: World, activity: Dictionary[Observer, bool]) -> void:
	# Pinned GECS exposes no silent public reseed; this adapter owns its derived monitor index.
	var entries_by_observer: Dictionary = world.get("_obs_entries_by_observer") as Dictionary
	for entries_value: Variant in entries_by_observer.values():
		var entries: Array = entries_value as Array
		for entry: Dictionary in entries:
			if bool(entry.get("is_monitor", false)):
				(entry.membership as Dictionary).clear()
				world.call("_seed_monitor_membership", entry, false)

	for observer: Observer in activity:
		observer.active = activity[observer]
#endregion
