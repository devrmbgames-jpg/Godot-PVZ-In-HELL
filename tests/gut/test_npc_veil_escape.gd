extends GutTest
## Native conditional escape, physical visibility and synchronous lifecycle cleanup.

const VAMPIRE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_vampire.tres"
)
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const ENTITY_SCRIPT: GDScript = preload("res://addons/gecs/ecs/entity.gd")
const ESCAPE: BehaviorTree = preload("res://content/domains/npc/ai/trees/bt_npc_veil_escape.tres")
const EMERGENCY: BehaviorTree = preload("res://content/domains/npc/ai/trees/bt_npc_emergency.tres")

var _root: Node3D
var _world: World
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _awareness: C_NpcAwareness
var _decision: C_NpcDecision
var _veil: C_NpcVeil
var _exit_position: Vector3 = Vector3(4, 0, 0)


class ExitMutator extends Observer:
	var retire: bool = false


	func query() -> QueryBuilder:
		return q.with_all([C_NpcIdentity]).on_event(NpcRoleInterruptionRequest.EVENT)


	func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
		var request: NpcRoleInterruptionRequest = payload as NpcRoleInterruptionRequest
		if request.kind != NpcRoleInterruptionRequest.Kind.FLEE_EXIT:
			return
		if retire:
			_world.remove_entity(entity)
			entity.free()
		else:
			DistrictPopulationService.reset_brain(entity as E_DistrictNpc)


#region Real native fixture
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	NpcCustomerComposition.install(_world)
	var session: Entity = Entity.new()
	var district: C_District = C_District.new()
	district.definition = DISTRICT.duplicate() as DEF_District
	var portal: DEF_DistrictPlace = DEF_DistrictPlace.new()
	portal.key = &"veil/exit"
	portal.kind = DEF_DistrictPlace.Kind.PORTAL
	portal.position = _exit_position
	district.definition.places = [portal]
	session.component_resources = [district, C_DayCycle.new(), C_CustomerFlow.new()]
	_world.add_entity(session)
	district = session.get_component(C_District) as C_District
	_person = NpcRecord.new()
	_person.npc_id = &"veil/vampire"
	_person.profile = VAMPIRE
	_person.variation = NpcVariationRules.create(VAMPIRE, 1234, _person.npc_id, 1)
	_person.placement = NpcRecord.Placement.STREET
	_person.phase_complete = true
	_person.portal_id = portal.key
	district.people.append(_person)
	_actor = (load(VAMPIRE.npc_scene_path) as PackedScene).instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, district.definition)
	assert_true(EntityCompositionService.try_register(context))
	_actor.freeze = true
	_actor.place_at(Vector3.ZERO)
	_awareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness
	_decision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	_veil = _actor.get_component(C_NpcVeil) as C_NpcVeil
	NpcBrainService.bind_engine(_actor)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(ENTITY_SCRIPT)
	_player = player_body as Node as Entity
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new(), C_Living.new()]
	_world.add_entity(_player)
	player_body.global_position = Vector3.FORWARD
	_world.add_observer(O_Damage.new())
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		_world.remove_entity(entity)
	_world.purge(false)
	ECS.world = null
	_root.free()


func _step() -> void:
	NpcAiFixture.traits(_actor, _person, _player, 0.2)
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(_actor, 0.2)


func _use_escape() -> void:
	(_actor.get_node("Brain") as BTPlayer).behavior_tree = ESCAPE


func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent


func _body() -> Node3D:
	return _actor.get_node("Body") as Node3D


func _cloud() -> Node3D:
	return _actor.get_node("VeilPresence/Cloud") as Node3D


func _hazard() -> Entity:
	var spatial: Node3D = Node3D.new()
	spatial.set_script(ENTITY_SCRIPT)
	var effect: Entity = spatial as Node as Entity
	var definition: DEF_ToxicArea = DEF_ToxicArea.new()
	definition.radius = 1.0
	definition.damage_per_tick = 20.0
	var state: C_Hazard = C_Hazard.new()
	state.definition = definition
	effect.component_resources = [state, C_ToxicArea.new()]
	_world.add_entity(effect)
	spatial.global_position = Vector3.UP * NpcPerceptionService.TORSO_HEIGHT
	return effect


func _start_flight() -> void:
	var health: C_Health = _actor.get_component(C_Health) as C_Health
	health.current = health.value * 0.2
	assert_true(NpcPerceptionService.can_see(_actor, _player, _person))
	_awareness.player_visible = true
	_awareness.has_last_seen = true
	_awareness.last_seen_position = (_player as Node as Node3D).global_position
	assert_true(CombatService.bind_target(_actor, _player))
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
#endregion


#region Conditions, real damage and native movement
func test_ordinary_bright_vampire_remains_visible_without_danger() -> void:
	_use_escape()
	assert_not_null(NpcVeilQueries.rule_for(_person))
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_eq(_veil.task_id, 0)
	assert_true(_body().visible)
	assert_false(_cloud().visible)
	assert_false(_awareness.fleeing)


func test_real_hazard_uses_cloud_and_physical_intent_without_immunity_or_teleport() -> void:
	_use_escape()
	var hazard: Entity = _hazard()
	var pose: Transform3D = _actor.global_transform
	var layer: int = _actor.collision_layer
	var mask: int = _actor.collision_mask
	var health: C_Health = _actor.get_component(C_Health) as C_Health
	var previous: float = health.current
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
	assert_true(_cloud().visible)
	assert_false(_body().visible)
	assert_true(_intent().movement_active)
	assert_ne(_intent().move_position, _actor.global_position)
	assert_eq(_actor.global_transform, pose)
	assert_eq(_actor.collision_layer, layer)
	assert_eq(_actor.collision_mask, mask)
	var request: DamageRequest = DamageRequest.new()
	request.target = _actor
	request.amount = 10.0
	DamageRequestService.submit(request)
	assert_lt(health.current, previous)
	_world.remove_entity(hazard)
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_true(_body().visible)
	assert_false(_intent().movement_active)


func test_confirmed_threat_starts_cloud_and_loss_of_sight_selects_invisibility() -> void:
	_use_escape()
	_start_flight()
	assert_true(_awareness.fleeing)
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_intent().move_position, _exit_position)
	(_player as Node as Node3D).global_position = Vector3(100, 0, 0)
	_awareness.player_visible = NpcPerceptionService.can_see(_actor, _player, _person)
	assert_false(_awareness.player_visible)
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.INVISIBLE)
	assert_true(NpcVeilQueries.concealed(_actor))
	assert_false(_body().visible)
	assert_false(_cloud().visible)
	assert_true(_intent().movement_active)
	assert_true(_awareness.has_last_seen)
	(_player as Node as Node3D).global_position = Vector3.FORWARD
	_awareness.player_visible = NpcPerceptionService.can_see(_actor, _player, _person)
	assert_true(_awareness.player_visible)
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
	assert_true(_cloud().visible)
	assert_true(_intent().movement_active)


func test_a_hidden_bound_target_does_not_start_the_typed_flight() -> void:
	_use_escape()
	(_actor.get_component(C_Health) as C_Health).current = 20.0
	(_player as Node as Node3D).global_position = Vector3(100, 0, 0)
	assert_true(CombatService.bind_target(_actor, _player))
	assert_false(NpcPerceptionService.can_see(_actor, _player, _person))
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_false(_awareness.fleeing)
	assert_same(CombatQueries.target_for(_actor), _player)


func test_optional_capability_can_disable_concealment_and_be_reused_on_another_profile() -> void:
	_use_escape()
	var profile: DEF_NpcArchetype = DEF_NpcArchetype.new()
	var rule: DEF_NpcVeil = NpcVeilQueries.rule_for(_person).duplicate() as DEF_NpcVeil
	rule.allow_invisible_escape = false
	profile.rules = [rule]
	_person.profile = profile
	_person.variation = NpcVariation.new()
	_awareness.fleeing = true
	_awareness.has_last_seen = true
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
	assert_false(NpcVeilQueries.concealed(_actor))


func test_native_route_abandonment_reveals_actor_and_uses_bounded_retry() -> void:
	_use_escape()
	_hazard()
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
	NpcIntentService.stop(_actor)
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_eq(_veil.task_id, 0)
	_step()
	assert_false(_intent().movement_active)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
#endregion


#region Actual lifecycle and view boundaries
func test_reset_dormancy_and_profile_replacement_restore_original_visibility() -> void:
	_use_escape()
	var label: Node3D = _actor.get_node("DebugStatus") as Node3D
	label.visible = false
	_hazard()
	_step()
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
	DistrictPopulationService.reset_brain(_actor)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_true(_body().visible)
	assert_false(label.visible)
	assert_false(_cloud().visible)
	NpcBrainService.bind_engine(_actor)
	_use_escape()
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
	NpcBrainService.set_participating(_actor, false)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_true(_body().visible)
	assert_false(_intent().movement_active)
	_decision.active_task_id = 42
	assert_true(NpcVeilService.claim(_actor, C_NpcVeil.Form.INVISIBLE, 42))
	var cloud_material: Material = (
		_actor.get_node("VeilPresence/Cloud/Low") as MeshInstance3D
	).material_override
	_actor.present_profile(VAMPIRE)
	assert_true(_body().visible)
	assert_false(label.visible)
	assert_same(
		(_actor.get_node("VeilPresence/Cloud/Low") as MeshInstance3D).material_override,
		cloud_material,
	)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)


func test_replacement_task_ownership_survives_the_old_leaf_exit() -> void:
	_use_escape()
	_hazard()
	_step()
	var old_token: int = _veil.task_id
	assert_ne(old_token, 0)
	_decision.active_task_id = 987
	assert_true(NpcVeilService.claim(_actor, C_NpcVeil.Form.INVISIBLE, 987))
	NpcVeilService.release(_actor, old_token)
	assert_eq(_veil.form, C_NpcVeil.Form.INVISIBLE)
	assert_eq(_veil.task_id, 987)
	NpcVeilService.release(_actor, 987)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)


func test_death_and_brainless_participation_clear_the_form_synchronously() -> void:
	_decision.active_task_id = 42
	assert_true(NpcVeilService.claim(_actor, C_NpcVeil.Form.INVISIBLE, 42))
	_actor.get_node("Brain").free()
	NpcBrainService.set_participating(_actor, false)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	_decision.active_task_id = 42
	assert_true(NpcVeilService.claim(_actor, C_NpcVeil.Form.CLOUD, 42))
	_actor.add_component(C_Death.new())
	_actor.sync_death_presentation()
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_true(_body().visible)
	assert_false(_cloud().visible)


func test_native_portal_completion_releases_form_and_keeps_the_retained_body() -> void:
	_use_escape()
	_world.add_observer(O_DistrictLifecycle.new())
	_start_flight()
	_actor.place_at(_exit_position)
	_step()
	assert_eq(_person.placement, NpcRecord.Placement.OUTSIDE)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_eq(_veil.task_id, 0)
	assert_false(_actor.enabled)
	assert_false(_awareness.fleeing)
	assert_eq(_awareness.flee_portal_id, &"")
	assert_false(_intent().movement_active)


func test_synchronous_exit_reset_does_not_complete_a_replaced_flight() -> void:
	_use_escape()
	_world.add_observer(ExitMutator.new())
	_world.add_observer(O_DistrictLifecycle.new())
	_start_flight()
	_actor.place_at(_exit_position)
	_step()
	assert_eq(_person.placement, NpcRecord.Placement.STREET)
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_false(_awareness.fleeing)
	assert_false(_intent().movement_active)


func test_synchronous_exit_retirement_does_not_access_a_freed_actor() -> void:
	_use_escape()
	var observer: ExitMutator = ExitMutator.new()
	observer.retire = true
	_world.add_observer(observer)
	_start_flight()
	_actor.place_at(_exit_position)
	_step()
	assert_false(is_instance_valid(_actor))


func test_actual_perception_sees_cloud_but_cannot_identify_an_invisible_body() -> void:
	var district: C_District = NpcPopulationQueries.current()
	var witness: NpcRecord = NpcRecord.new()
	witness.npc_id = &"veil/witness"
	witness.profile = VAMPIRE
	witness.variation = NpcVariationRules.create(VAMPIRE, 1234, witness.npc_id, 1)
	witness.placement = NpcRecord.Placement.STREET
	district.people.append(witness)
	var observer: E_DistrictNpc = (
		(load(VAMPIRE.npc_scene_path) as PackedScene).instantiate() as E_DistrictNpc
	)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		observer,
		_world,
		String(witness.npc_id),
	)
	NpcConstructionService.configure_context(context, witness, district.definition)
	assert_true(EntityCompositionService.try_register(context))
	observer.freeze = true
	observer.place_at(Vector3(0, 0, 2))
	await get_tree().physics_frame
	assert_true(NpcPerceptionService.can_see(observer, _actor, witness))
	_decision.active_task_id = 42
	assert_true(NpcVeilService.claim(_actor, C_NpcVeil.Form.CLOUD, 42))
	assert_true(NpcPerceptionService.can_see(observer, _actor, witness))
	assert_true(NpcVeilService.claim(_actor, C_NpcVeil.Form.INVISIBLE, 42))
	assert_false(NpcPerceptionService.can_see(observer, _actor, witness))
	assert_false(
		NpcPerceptionService.can_see_point(
			observer,
			_actor.global_position + Vector3.UP,
			witness,
			_actor,
		)
	)
	NpcVeilService.release(_actor, 42)
	assert_true(NpcPerceptionService.can_see(observer, _actor, witness))


func test_higher_native_freeze_preempts_cloud_without_stale_form_or_movement() -> void:
	(_actor.get_node("Brain") as BTPlayer).behavior_tree = load(NpcBrainService.TREE_PATH)
	_hazard()
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.CLOUD)
	var gaze: C_NpcGazeFreeze = _actor.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
	gaze.rule = DEF_NpcGazeFreeze.new()
	gaze.observed = true
	_step()
	assert_eq(_veil.form, C_NpcVeil.Form.VISIBLE)
	assert_eq(_veil.task_id, 0)
	assert_false(_cloud().visible)
	assert_true(_body().visible)
	assert_false(_intent().movement_active)


func test_both_authored_roots_share_conditional_native_escape() -> void:
	assert_same((EMERGENCY.get_root_task().get_child(0) as BTSubtree).subtree, ESCAPE)
	assert_is(ESCAPE.get_root_task(), BTDynamicSequence)
	assert_eq(ESCAPE.get_root_task().get_child_count(), 2)
	for path: String in [
		NpcBrainService.TREE_PATH,
		"res://content/domains/customers/ai/trees/bt_district_npc.tres",
	]:
		var tree: BehaviorTree = load(path) as BehaviorTree
		var index: int = 2 if path == NpcBrainService.TREE_PATH else 1
		assert_same((tree.get_root_task().get_child(index) as BTSubtree).subtree, EMERGENCY)
#endregion
