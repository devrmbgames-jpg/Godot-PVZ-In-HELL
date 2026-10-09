extends GutTest
## Exercises project World preparation before pinned registration and deferred System.setup.

const SAVE_PATH: String = "user://refactoring_v2_41_placed_bootstrap.pvzh"


## Minimal real level contract consumed by the existing save/startup boundary.
class FixtureLevel extends Node:
	## Empty path keeps this fixture outside live user slots.
	var autosave_path: String = ""


## Counts pinned registration calls; the project World must prepare every placed actor first.
class CountingWorld extends GameWorld:
	var _registrations: int = 0

	## Records the one native registration of each placed scene actor.
	func add_entity(actor: Entity, components: Variant = null,
			add_to_tree: bool = true) -> void:
		_registrations += 1
		super.add_entity(actor, components, add_to_tree)

	## Returns the number of native calls made by automatic World.initialize.
	func registrations() -> int:
		return _registrations


## Passive native ready reports complete data without emitting gameplay commands/outcomes.
class PassiveActor extends Entity:
	var _native_ready_calls: int = 0
	var _ready_components: int = 0

	## Counts native readiness while leaving gameplay state untouched.
	func on_ready() -> void:
		_native_ready_calls += 1
		_ready_components = components.size()

	## Returns the number of native initialization callbacks.
	func ready_calls() -> int:
		return _native_ready_calls

	## Returns data visible at the native on_ready boundary.
	func ready_components() -> int:
		return _ready_components


## Captures durable fields and the physical owner at the actual native initialization callback.
class SavedStateActor extends PassiveActor:
	var _construction_state: Dictionary = {}

	## Reads prepared state before any later persistence overlay can run.
	func on_ready() -> void:
		super.on_ready()
		var health: C_Health = get_component(C_Health) as C_Health
		var spatial: Node3D = self as Node as Node3D
		var marks: C_PackageMarks = get_component(C_PackageMarks) as C_PackageMarks
		var anchored: C_PlayerAnchored = get_component(C_PlayerAnchored) as C_PlayerAnchored
		var original: Dictionary = {}
		if anchored != null:
			original = {"freeze": anchored.snapshot.freeze,
				"freeze_mode": anchored.snapshot.freeze_mode,
				"can_sleep": anchored.snapshot.can_sleep}
		_construction_state = {"health": health.current, "id": id,
			"pose": spatial.global_transform, "death": has_component(C_Death),
			"ink_points": marks.point_count if marks != null else 0,
			"completed": PersistentInteractionState.completed(self),
			"anchored": anchored != null, "frozen": (spatial as RigidBody3D).freeze,
			"anchor_original": original}

	## Returns the fields seen by pinned native initialization.
	func construction_state() -> Dictionary:
		return _construction_state.duplicate()


## Deferred setup confirms compilation never binds ECS.world early.
class SetupProbe extends System:
	var _setup_calls: int = 0
	var _setup_entities: int = 0
	var _process_calls: int = 0

	## Records the World contents when normal ECS.world binding finalizes setup.
	func setup() -> void:
		_setup_calls += 1
		_setup_entities = _world.entities.size()

	## Selects actual fixture data for scheduled execution after global readiness.
	func query() -> QueryBuilder:
		return q.with_all([C_DayCycle])

	## Counts real native System execution; no gameplay effects are synthesized by the test.
	func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
		_process_calls += 1

	## Returns the actual scheduler dispatch count.
	func process_calls() -> int:
		return _process_calls

	## Returns the number of normal native setup invocations.
	func setup_calls() -> int:
		return _setup_calls

	## Returns the number of fully registered actors visible to passive setup.
	func setup_entities() -> int:
		return _setup_entities


var _level: FixtureLevel = null
var _world: CountingWorld = null
var _actors: Node = null
var _systems: Node = null

#region Prepared fixture lifetime
func before_each() -> void:
	_level = FixtureLevel.new()
	_level.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	_actors = Node.new()
	_actors.name = "Actors"
	_level.add_child(_actors)
	_systems = Node.new()
	_systems.name = "Systems"
	_level.add_child(_systems)
	_world = CountingWorld.new()
	_world.name = "World"
	_world.entity_nodes_root = NodePath("../Actors")
	_world.system_nodes_root = NodePath("../Systems")
	_level.add_child(_world)


func after_each() -> void:
	if ECS.world == _world:
		ECS.world = null
	_world.purge(false)
	_level.free()
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _saved_actor(recipe: C_Health) -> SavedStateActor:
	var spatial: RigidBody3D = RigidBody3D.new()
	spatial.set_script(SavedStateActor)
	var actor: SavedStateActor = spatial as Node as SavedStateActor
	actor.name = "Subject"
	var action: DEF_InteractionAction = DEF_InteractionAction.new()
	action.action_id = &"fixture_never"
	action.timing = DEF_ProlongedInteraction.new()
	action.timing.reset_policy = DEF_ProlongedInteraction.ResetPolicy.NEVER
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [action]
	actor.component_resources = [recipe, C_Anchorable.new(), actions]
	actor.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"Subject")
	_actors.add_child(actor)
	actor.owner = _level
	return actor


func _write_saved_fixture(terminal_state: bool = false) -> Dictionary:
	_actor("Session", [C_DayCycle.new()])
	var source: SavedStateActor = _saved_actor(C_Health.new())
	source.id = "saved/Subject"
	add_child(_level)
	ECS.world = _world
	(source.get_component(C_Health) as C_Health).current = 37.0
	(source as Node as Node3D).global_position = Vector3(2.0, 3.0, 4.0)
	if terminal_state:
		(source.get_component(C_Health) as C_Health).current = 0.0
		source.add_component(C_Death.new())
		var marks: C_PackageMarks = C_PackageMarks.new()
		var stroke: PackageMarkStroke = PackageMarkStroke.new()
		stroke.points = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])
		marks.strokes = [stroke]
		marks.point_count = 2
		source.add_component(marks)
		var anchored: C_PlayerAnchored = C_PlayerAnchored.new()
		anchored.snapshot = AnchoredBodySnapshot.new()
		anchored.snapshot.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		anchored.snapshot.can_sleep = false
		source.add_component(anchored)
		(source as Node as RigidBody3D).freeze = true
		PersistentInteractionState.restore([&"fixture_never"], source)
	var snapshot: Dictionary = WorldSnapshotService.capture(_level, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _level))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)

	# Rebuild a separate native tree with the same authored identity and untouched defaults.
	ECS.world = null
	_world.purge(false)
	_level.free()
	before_each()
	_level.autosave_path = SAVE_PATH
	return snapshot


func _actor(label: String, recipes: Array[Component]) -> PassiveActor:
	var actor: PassiveActor = PassiveActor.new()
	actor.name = label
	actor.component_resources = recipes
	actor.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(label))
	_actors.add_child(actor)
	actor.owner = _level
	return actor


func _template_actor(actor: Entity, capability_id: StringName,
		recipes: Array[Component]) -> EntityAuthoring:
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = DEF_EntityTemplate.new()
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = capability_id
	capability.component_recipes = recipes
	authoring.entity_template.traits = [capability]
	actor.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	return authoring
#endregion

#region Whole placed preparation
## Intrinsic scene and Template data initialize once, before normal passive System.setup.
func test_placed_recipes_prepare_before_native_registration_and_deferred_setup() -> void:
	var actor: PassiveActor = _actor("Actor", [C_DayCycle.new()])
	_template_actor(actor, &"resistance", [C_DamageResistance.new()])
	var probe: SetupProbe = SetupProbe.new()
	_systems.add_child(probe)
	probe.owner = _level
	var previous_world: World = ECS.world
	add_child(_level)
	assert_false(_world.initialization_failed())
	assert_eq(_world.registrations(), 1)
	assert_eq(actor.ready_calls(), 1)
	assert_eq(actor.ready_components(), 3, "Scene, Trait and authored identity are complete")
	assert_eq(probe.setup_calls(), 0)
	assert_eq(ECS.world, previous_world)
	ECS.world = _world
	assert_eq(probe.setup_calls(), 1)
	assert_eq(probe.setup_entities(), 1)
	assert_eq(_world.registrations(), 1)


## One provider conflict aborts the complete placed set before any actor's native on_ready.
func test_duplicate_provider_aborts_all_placed_registration_without_side_effects() -> void:
	var neighbour: PassiveActor = _actor("Neighbour", [C_DamageResistance.new()])
	var invalid: PassiveActor = _actor("Invalid", [C_DayCycle.new()])
	_template_actor(invalid, &"duplicate", [C_DayCycle.new()])
	add_child(_level)
	assert_true(_world.initialization_failed())
	assert_eq(_world.registrations(), 0)
	assert_eq(_world.entities.size(), 0)
	assert_eq(_world.entity_id_registry.size(), 0)
	assert_eq(neighbour.ready_calls(), 0)
	assert_eq(invalid.ready_calls(), 0)
	assert_false(EntityCompositionService.recipes_prepared(neighbour))
	assert_false(EntityCompositionService.recipes_prepared(invalid))
	assert_eq(neighbour.id, "")
	assert_eq(invalid.id, "")
	assert_true(_world.composition_issues().any(func(issue: EntityBuildPlan.Issue) -> bool:
		return issue.code == &"duplicate_provider"))


## The pre-native gate prevents GECS's replacement policy for repeated authored Entity IDs.
func test_duplicate_entity_id_is_rejected_before_native_collision_replacement() -> void:
	var first: PassiveActor = _actor("First", [])
	var second: PassiveActor = _actor("Second", [])
	first.id = "repeated/id"
	second.id = "repeated/id"
	add_child(_level)
	assert_true(_world.initialization_failed())
	assert_eq(_world.registrations(), 0)
	assert_eq(first.ready_calls(), 0)
	assert_eq(second.ready_calls(), 0)
	assert_false(first.is_queued_for_deletion())
	assert_false(second.is_queued_for_deletion())
	assert_eq(_world.entity_id_registry.size(), 0)


## A later-declared endpoint is validated as part of the same set and bound after both registrations.
func test_initial_binding_uses_fully_registered_endpoint_from_the_placed_set() -> void:
	var source: PassiveActor = _actor("Source", [])
	var target: PassiveActor = _actor("Target", [])
	var authoring: EntityAuthoring = _template_actor(source, &"mounted", [])
	authoring.bindings[&"support"] = NodePath("../Target")
	var intent: EntityInitialBinding = EntityInitialBinding.new()
	intent.relation = R_SlotMountedOn.new()
	intent.endpoint = &"support"
	authoring.entity_template.traits[0].initial_bindings = [intent]
	add_child(_level)
	assert_false(_world.initialization_failed())
	assert_eq(_world.registrations(), 2)
	assert_eq(source.relationships.size(), 1)
	assert_eq(source.relationships[0].target, target)
	assert_ne(source.relationships[0].relation, intent.relation)
	assert_gt(target.ecs_id, 0)
	assert_eq(source.ready_calls(), 1)
	assert_eq(target.ready_calls(), 1)
#endregion

#region District construction before native registration
## The same prepass gives placed merchant identity and fresh roster before ECS.world binding.
func test_placed_district_roster_and_merchant_identity_precede_native_publication() -> void:
	var district: C_District = C_District.new()
	district.definition = load(
		"res://content/domains/npc/definitions/def_district_default.tres") as DEF_District
	var session: PassiveActor = _actor("Session", [district, C_DayCycle.new()])
	var authoring: EntityAuthoring = EntityAuthoring.new()
	authoring.entity_template = load(
		"res://content/domains/npc/definitions/def_entity_district_session.tres") as DEF_EntityTemplate
	session.set_meta(EntityCompositionService.AUTHORING_META, authoring)
	var prefab: PackedScene = load(
		"res://content/domains/npc/entities/district_npc.tscn") as PackedScene
	var merchant: E_DistrictNpc = prefab.instantiate() as E_DistrictNpc
	merchant.name = "Trader"
	merchant.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"Trader")
	_actors.add_child(merchant)
	merchant.owner = _level
	var inspection_slot: Entity = merchant.get_node("InspectionParcelSlot") as Entity
	inspection_slot.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"merchant_inspection_slot")
	var publications: Array[StringName] = []
	_world.entity_added.connect(func(actor: Entity) -> void:
		if actor == merchant:
			publications.append((actor.get_component(C_NpcIdentity) as C_NpcIdentity).npc_id))
	var previous_world: World = ECS.world
	add_child(_level)
	var diagnostics: Array[String] = _world.identity_issues()
	for issue: EntityBuildPlan.Issue in _world.composition_issues():
		diagnostics.append("%s: %s" % [issue.code, issue.message])
	assert_false(_world.initialization_failed(), str(diagnostics))
	if _world.initialization_failed():
		return
	assert_eq(_world.registrations(), 3)
	assert_eq(publications, [&"npc/8"])
	assert_eq(ECS.world, previous_world)
	var committed: C_District = session.get_component(C_District) as C_District
	assert_eq(committed.people.size(), district.definition.profiles.size())
	assert_eq(committed.next_person, 1 + committed.people.size())
	assert_true(district.people.is_empty(), "Scene recipes remain immutable")
	assert_true(committed.people[7].profile.merchant)
#endregion


#region First scheduled tick barrier
## Passive setup may bind before startup closes, but scheduled consumers wait for global ready.
func test_first_scheduled_tick_waits_for_accepted_startup() -> void:
	_actor("Actor", [C_DayCycle.new()])
	var probe: SetupProbe = SetupProbe.new()
	_systems.add_child(probe)
	probe.owner = _level
	add_child(_level)
	ECS.world = _world
	assert_eq(probe.setup_calls(), 1)
	assert_false(_world.composition_ready())
	_world.process(0.1)
	assert_eq(probe.process_calls(), 0)
	_world.finish_startup()
	assert_true(_world.composition_ready())
	_world.process(0.1)
	assert_eq(probe.process_calls(), 1)
#endregion


#region Late startup Observer registration
## Native and late startup observers use the same suspension path and never replay initial matches.
func test_late_startup_observer_is_suspended_until_all_initial_entities_are_complete() -> void:
	_actor("Initial", [C_Health.new()])
	add_child(_level)
	ECS.world = _world
	var spy: O_StartupEffectSpy = O_StartupEffectSpy.new()
	_world.add_observer(spy)
	assert_false(spy.active)
	var startup_actor: Entity = Entity.new()
	startup_actor.component_resources = [C_Health.new()]
	EntityCompositionFixture.register(_world, startup_actor)
	assert_eq(spy.effects, 0)
	_world.finish_startup()
	assert_true(spy.active)
	assert_eq(spy.effects, 0, "Initial membership is rebuilt without gameplay replay")
	var future_actor: Entity = Entity.new()
	future_actor.component_resources = [C_Health.new()]
	EntityCompositionFixture.register(_world, future_actor)
	assert_eq(spy.effects, 1)
#endregion


#region Saved placed state before native initialization
## Native ready and publication both see restored fields, identity and physical pose.
func test_saved_placed_state_is_complete_before_native_ready_and_publication() -> void:
	_write_saved_fixture()
	_actor("Session", [C_DayCycle.new()])
	var prototype: C_Health = C_Health.new()
	var original_health: float = prototype.current
	var subject: SavedStateActor = _saved_actor(prototype)
	var publications: Array[Dictionary] = []
	_world.entity_added.connect(func(actor: Entity) -> void:
		if actor == subject:
			publications.append(subject.construction_state()))
	add_child(_level)

	assert_false(_world.initialization_failed())
	assert_true(_world.restoring_startup())
	assert_false(_world.composition_ready())
	assert_eq(_world.registrations(), 2)
	assert_eq(subject.ready_calls(), 1)
	var expected: Dictionary = {"health": 37.0, "id": "saved/Subject",
		"pose": Transform3D(Basis.IDENTITY, Vector3(2.0, 3.0, 4.0)), "death": false,
		"ink_points": 0, "completed": [], "anchored": false, "frozen": false,
		"anchor_original": {}}
	assert_eq(subject.construction_state(), expected)
	assert_eq(publications, [expected])
	assert_eq(prototype.current, original_health, "Authored recipe stays immutable")
	assert_eq((subject.get_component(C_Health) as C_Health).current, 37.0)
	assert_false(EntityCompositionService.composition_ready(subject))
	_world.finish_startup()
	assert_true(EntityCompositionService.composition_ready(subject))


## A valid record requiring a missing physical owner rejects before native registration.
func test_incompatible_saved_pose_rejects_before_preparing_or_registering_placed_actors() -> void:
	var snapshot: Dictionary = _write_saved_fixture()
	var session: PassiveActor = _actor("Session", [C_DayCycle.new()])
	var prototype: C_Health = C_Health.new()
	var subject: PassiveActor = _actor("Subject", [prototype])
	assert_true(WorldSnapshotService.valid(snapshot, _level))
	assert_false(WorldSnapshotService.can_restore(snapshot, _level))
	var original_health: float = prototype.current
	add_child(_level)

	assert_true(_world.initialization_failed())
	assert_eq(_world.registrations(), 0)
	assert_eq(_world.entities.size(), 0)
	assert_eq(subject.ready_calls(), 0)
	assert_eq(session.ready_calls(), 0)
	assert_eq(subject.id, "")
	assert_false(EntityCompositionService.recipes_prepared(subject))
	assert_false(EntityCompositionService.recipes_prepared(session))
	assert_eq(prototype.current, original_health)
	assert_true(_world.composition_issues().any(func(issue: EntityBuildPlan.Issue) -> bool:
		return issue.code == &"invalid_saved_composition"))
#endregion

#region Saved runtime markers before native callbacks
## Native initialization and publication see terminal markers, private ink and completed NEVER data.
func test_saved_runtime_markers_are_complete_before_placed_native_ready() -> void:
	var snapshot: Dictionary = _write_saved_fixture(true)
	_actor("Session", [C_DayCycle.new()])
	var subject: SavedStateActor = _saved_actor(C_Health.new())
	var publications: Array[Dictionary] = []
	_world.entity_added.connect(func(actor: Entity) -> void:
		if actor == subject:
			publications.append(subject.construction_state()))
	add_child(_level)

	var expected: Dictionary = {"health": 0.0, "id": "saved/Subject",
		"pose": Transform3D(Basis.IDENTITY, Vector3(2.0, 3.0, 4.0)), "death": true,
		"ink_points": 2, "completed": [&"fixture_never"], "anchored": true, "frozen": true,
		"anchor_original": {"freeze": false, "freeze_mode": RigidBody3D.FREEZE_MODE_KINEMATIC,
			"can_sleep": false}}
	assert_false(_world.initialization_failed())
	assert_eq(subject.ready_calls(), 1)
	assert_eq(publications, [expected])
	assert_eq(subject.construction_state(), expected)
	var marks: C_PackageMarks = subject.get_component(C_PackageMarks) as C_PackageMarks
	assert_eq(marks.strokes[0].points, PackedVector3Array([Vector3.ZERO, Vector3.RIGHT]))
	for record: Dictionary in snapshot.entities:
		if String(record.entity_id) == subject.id:
			var saved: Dictionary = (record.ink as Array)[0] as Dictionary
			var points: PackedVector3Array = saved.points as PackedVector3Array
			points[0] = Vector3.UP
			assert_eq(marks.strokes[0].points[0], Vector3.ZERO)
	assert_false(EntityCompositionService.composition_ready(subject))
#endregion
