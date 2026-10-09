extends World
## Prepares the complete placed recipe/identity graph before pinned native World registration.
class_name GameWorld

var _identity_issues: Array[String] = []
var _composition_issues: Array[EntityBuildPlan.Issue] = []
var _placed_actors: Array[Entity] = []
var _placed_plans: Array[EntityBuildPlan] = []
var _startup_activity: Dictionary[Observer, bool] = {}
var _restoring: bool = false
var _starting: bool = true

#region Validated world registration
func _ready() -> void:
	_identity_issues = PlacedIdentityRules.compile_for(get_parent())
	if not _identity_issues.is_empty():
		return
	var level: Node = get_parent()
	var candidate: Dictionary = GameSessionService.startup_snapshot(level,
		String(level.get("autosave_path")))
	var construction_snapshot: Dictionary = candidate \
		if not candidate.is_empty() and WorldSnapshotService.valid(candidate, level) else {}
	_restoring = not construction_snapshot.is_empty()
	if _restoring and not WorldSnapshotService.can_restore(construction_snapshot, level):
		var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
		issue.code = &"invalid_saved_composition"
		issue.message = "Saved state does not match the current authored composition"
		issue.instance_path = String(level.get_path())
		issue.source = "saved construction preflight"
		_composition_issues.append(issue)
		return
	if not _prepare_placed_recipes(construction_snapshot):
		return
	super._ready()
	_bind_placed_intents()
	_placed_actors.clear()
	_placed_plans.clear()


## Reports rejected authored identity without partially registering actors or starting simulation.
func initialization_failed() -> bool:
	return not _identity_issues.is_empty() or not _composition_issues.is_empty()


## Returns a copy of actionable authoring diagnostics for the composition owner.
func identity_issues() -> Array[String]:
	return _identity_issues.duplicate()


## Returns structured compile/identity/endpoint diagnostics before simulation can start.
func composition_issues() -> Array[EntityBuildPlan.Issue]:
	return _composition_issues.duplicate()


## Reports the passive startup transaction to the level composition owner.
func restoring_startup() -> bool:
	return _restoring


## Adds composition observers without enabling gameplay before all startup fixup completes.
func add_observer(observer: Observer) -> void:
	if _starting:
		_startup_activity[observer] = observer.active
		observer.active = false
	super.add_observer(observer)


## Publishes readiness after all state, links and derived bindings have been reconstructed.
func finish_startup() -> void:
	assert(_starting and not initialization_failed(), "Only accepted startup publishes readiness")
	ObserverReactionBoundary.resume(self, _startup_activity)
	_startup_activity.clear()
	_restoring = false
	_starting = false


## Reports accepted global readiness after defaults, startup spawns and restored links are complete.
func composition_ready() -> bool:
	return not _starting and not initialization_failed()


## Holds scheduled consumers until the level composition owner closes startup.
func process(delta: float, group: String = "") -> void:
	if not composition_ready():
		return
	super.process(delta, group)
#endregion


#region Whole placed composition
func _prepare_placed_recipes(snapshot: Dictionary) -> bool:
	# Match pinned discovery exactly; a missing default root contains no authored placed actors.
	var actor_root: Node = get_node_or_null(entity_nodes_root) \
		if not entity_nodes_root.is_empty() else null
	if actor_root == null:
		return true
	_placed_actors.assign(actor_root.find_children("*", "Entity"))
	var contexts: Array[EntitySpawnContext] = []
	var records: Array = snapshot.get("entities", []) as Array
	for actor: Entity in _placed_actors:
		var saved: Dictionary = WorldSnapshotService.construction_record(actor, records)
		var actor_id: String = (
			String(saved.entity_id) if not saved.is_empty()
			else (actor.id if not actor.id.is_empty() else GECSIO.uuid())
		)
		var context: EntitySpawnContext = EntityCompositionService.context_for(actor, self,
			actor_id, _placed_actors)
		contexts.append(context)

	# Roster and placed merchant identity are compiler inputs, before any native World callbacks.
	var npc_issues: PackedStringArray = NpcConstructionService.configure_placed(contexts,
		WorldSnapshotService.construction_district(records),
		WorldSnapshotService.construction_npc_identities(records))
	for message: String in npc_issues:
		var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
		issue.code = &"invalid_population"
		issue.message = message
		issue.instance_path = String(get_parent().get_path())
		issue.source = "district construction"
		_composition_issues.append(issue)
	if not _composition_issues.is_empty():
		return false
	for context: EntitySpawnContext in contexts:
		var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
		var saved: Dictionary = WorldSnapshotService.construction_record(context.actor, records)
		if plan.valid() and not WorldSnapshotService.overlay_construction_fields(plan, saved):
			var issue: EntityBuildPlan.Issue = EntityBuildPlan.Issue.new()
			issue.code = &"invalid_saved_fields"
			issue.message = "Saved state cannot overlay this placed composition"
			issue.instance_path = context.instance_path
			issue.source = "saved construction fields"
			plan.issues.append(issue)
		_placed_plans.append(plan)

	# Collision and endpoint checks precede every pinned add_entity/System.setup callback.
	if not EntityBuildRules.validate_registration_batch(contexts, _placed_plans):
		for plan: EntityBuildPlan in _placed_plans:
			_composition_issues.append_array(plan.issues)
		_placed_actors.clear()
		_placed_plans.clear()
		return false

	for build_index: int in _placed_actors.size():
		var actor: Entity = _placed_actors[build_index]
		var plan: EntityBuildPlan = _placed_plans[build_index]
		var prepared: bool = EntityCompositionService.prepare(actor, plan)
		assert(prepared, "Whole-set validation requires an uninitialized placed instance")
		actor.id = contexts[build_index].actor_id
		WorldSnapshotService.apply_placed_construction_pose(actor,
			WorldSnapshotService.construction_record(actor, records))
	return true


func _bind_placed_intents() -> void:
	# Native registration assigns every endpoint's numeric ID before the first live binding.
	for build_index: int in _placed_actors.size():
		var actor: Entity = _placed_actors[build_index]
		for binding: EntityBuildPlan.Binding in _placed_plans[build_index].bindings:
			assert(entities.has(actor) and entities.has(binding.target),
				"Initial binding endpoints require completed placed registration")
			actor.add_relationship(Relationship.new(binding.relation, binding.target))
#endregion


#region Registered disabled entities
## Stops participation while retaining structural tracking for persistent lifecycle changes.
func disable_entity(entity: Variant) -> Entity:
	var subject: Entity = super.disable_entity(entity)
	# Pinned GECS v8 disconnects these signals while keeping the Entity in its
	# archetype. Dormant persistent actors still receive reset/restore operations;
	# their Component/Relationship changes must keep that same native index current.
	subject.component_added.connect(_on_entity_component_added)
	subject.component_removed.connect(_on_entity_component_removed)
	subject.relationship_added.connect(_on_entity_relationship_added)
	subject.relationship_removed.connect(_on_entity_relationship_removed)
	subject.relationships_batch_added.connect(_on_entity_relationships_batch_added)
	subject.relationships_batch_removed.connect(_on_entity_relationships_batch_removed)
	return subject
#endregion
