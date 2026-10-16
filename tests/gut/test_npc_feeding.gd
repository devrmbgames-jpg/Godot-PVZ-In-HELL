extends GutTest
## Native feeding preference, perception, attack/Health bounds and lifecycle interruptions.

const VAMPIRE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_vampire.tres"
)
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const FEEDING: BehaviorTree = preload("res://content/domains/npc/ai/trees/bt_npc_feeding.tres")

var _root: Node3D
var _world: World
var _district: C_District
var _actor: E_DistrictNpc
var _person: NpcRecord
var _player: Entity
var _health: C_Health
var _awareness: C_NpcAwareness
var _decision: C_NpcDecision
var _combat: C_NpcCombat
var _damage: O_Damage


class FeedingReceiverMutator extends Observer:
	var retire: bool = false


	func query() -> QueryBuilder:
		return q.with_all([C_NpcIdentity]).on_event(NpcSocialReactionCommitted.EVENT)


	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		if retire:
			_world.remove_entity(entity)
			entity.free()
		else:
			DistrictPopulationService.reset_brain(entity as E_DistrictNpc)


#region Real native construction and due sensing
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
	district.definition = DISTRICT
	session.component_resources = [district, C_DayCycle.new(), C_CustomerFlow.new()]
	_world.add_entity(session)
	_district = session.get_component(C_District) as C_District
	_person = NpcRecord.new()
	_person.npc_id = &"feeding/vampire"
	_person.profile = VAMPIRE
	_person.variation = NpcVariationRules.create(VAMPIRE, 1234, _person.npc_id, 1)
	_person.placement = NpcRecord.Placement.STREET
	_person.phase_complete = true
	_district.people.append(_person)
	_actor = (load(VAMPIRE.npc_scene_path) as PackedScene).instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, DISTRICT)
	assert_true(EntityCompositionService.try_register(context))
	_actor.set_physics_process(false)
	_actor.place_at(Vector3.ZERO)
	_awareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness
	_decision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	_combat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	_combat.melee_attacks = [_combat.melee_attacks[0].duplicate() as DEF_NpcAttack]
	_combat.melee_attacks[0].damage = 1000.0
	_combat.automatic_attack_selection = false
	NpcBrainService.bind_engine(_actor)
	var player_body: CharacterBody3D = CharacterBody3D.new()
	player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	_player = player_body as Node as Entity
	_player.component_resources = [C_PlayerInputController.new(), C_Health.new(), C_Living.new()]
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	player_body.add_child(collision)
	_world.add_entity(_player)
	player_body.global_position = Vector3.FORWARD
	_health = _player.get_component(C_Health) as C_Health
	_damage = O_Damage.new()
	_world.add_observer(_damage)
	_world.add_observer(O_HealthLifecycle.new())
	var combat_owner: S_NpcCombat = S_NpcCombat.new()
	combat_owner.group = "FeedingFixture"
	_world.add_system(combat_owner)
	var projectiles: S_CombatProjectile = S_CombatProjectile.new()
	projectiles.group = "FeedingProjectile"
	_world.add_system(projectiles)
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_BloodAreaSetup.new())
	_world.add_observer(O_NpcBloodStimulus.new())
	await _sync_physics()


func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		_world.remove_entity(entity)
	_world.purge(false)
	ECS.world = null
	_root.free()


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _sense() -> void:
	NpcAiFixture.sense(_actor, _person, _player, 0.2)


func _step() -> void:
	_decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(_actor, 0.2)


func _start_attack() -> void:
	assert_true(CombatService.bind_target(_actor, _player))
	_sense()
	assert_true(NpcAttackService.start(_actor, C_NpcCombat.Kind.MELEE, 0))
#endregion


#region Preference and visible native tree priority
func test_native_visible_wounded_player_starts_feeding_without_fabricating_offense() -> void:
	_health.current = 60.0
	_sense()
	assert_true(_awareness.player_visible)
	assert_same(NpcFeedingTargetQueries.wounded_player_for(_actor), _player)
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_true(_awareness.target_visible)
	assert_eq(_decision.intent_owner, C_NpcDecision.Owner.COMBAT)
	assert_true(_person.memories.is_empty())
	assert_eq(_health.current, 60.0)
	_step()
	assert_eq(_combat.phase, C_NpcCombat.Phase.WINDUP)


func test_unseen_healthy_or_at_floor_players_do_not_motivate_feeding() -> void:
	for hp: float in [100.0, 76.0, 10.0, 5.0]:
		_health.current = hp
		_sense()
		assert_null(NpcFeedingTargetQueries.wounded_player_for(_actor))
	_health.current = 60.0
	(_player as Node as Node3D).global_position = Vector3.BACK * 3.0
	await _sync_physics()
	_sense()
	assert_false(_awareness.player_visible)
	assert_null(NpcFeedingTargetQueries.wounded_player_for(_actor))
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_true(_person.memories.is_empty())


func test_real_conversation_and_service_role_preserve_their_owners() -> void:
	_health.current = 60.0
	_sense()
	assert_true(NpcDialogueService.begin(_player, _actor))
	assert_null(NpcFeedingTargetQueries.wounded_player_for(_actor))
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_same(NpcDialogueService.participant(_actor), _player)
	NpcDialogueService.end(_actor)
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"feeding/service"
	visit.customer_id = _person.npc_id
	visit.definition = DEF_Customer.new()
	(CustomerFlowQueries.current() as C_CustomerFlow).visits.append(visit)
	assert_true(NpcServiceRole.begin(_actor, _person, visit, 1))
	assert_true(_actor.has_active_role())
	assert_null(NpcFeedingTargetQueries.wounded_player_for(_actor))
	assert_false(visit.finished)
	NpcServiceRole.release(_actor, visit.visit_id)


func test_perceived_blood_preempts_feeding_and_cancels_an_actual_windup() -> void:
	_health.current = 60.0
	_start_attack()
	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.request_id = "feeding/blood"
	request.origin_id = "feeding/blood"
	request.scene = load("res://content/domains/hazards/entities/blood_spill.tscn") as PackedScene
	var definition: DEF_BloodArea = DEF_BloodArea.new()
	definition.provokes_unclean = false
	request.definition = definition
	request.world_pose.origin = Vector3(1.0, 0.0, -2.0)
	assert_true(HazardSpawnService.submit(request))
	await _sync_physics()
	_sense()
	assert_true(NpcBloodQueries.calmed(_actor))
	assert_null(NpcFeedingTargetQueries.wounded_player_for(_actor))
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_combat.phase, C_NpcCombat.Phase.READY)
	_world.process(1.0, "FeedingFixture")
	assert_eq(_health.current, 60.0)


func test_authored_subtree_is_shared_and_ordinary_floor_can_be_reused_by_another_profile() -> void:
	assert_true(VAMPIRE.valid_rules())
	var rule: DEF_NpcFeeding = NpcFeedingQueries.rule_for(_actor)
	assert_not_null(rule)
	assert_eq(rule.minimum_health_fraction, 0.1)
	for entry: Dictionary in [
		{ "path": NpcBrainService.TREE_PATH, "index": 5 },
		{ "path": "res://content/domains/customers/ai/trees/bt_district_npc.tres", "index": 4 },
	]:
		var root_task: BTTask = (load(entry.path) as BehaviorTree).get_root_task()
		var index: int = entry.index as int
		assert_eq(root_task.get_child(index - 1).get_custom_name(), "Воспринятая кровь")
		assert_same((root_task.get_child(index) as BTSubtree).subtree, FEEDING)
		assert_eq(
			root_task.get_child(index + 1).get_custom_name(),
			"Игрушка / гордость и признанная сила",
		)
	var other: DEF_NpcArchetype = DEF_NpcArchetype.new()
	other.key = &"fixture/other_archetype"
	other.rules = [rule]
	_person.profile = other
	_health.current = 60.0
	_awareness.player_visible = true
	assert_same(NpcFeedingTargetQueries.wounded_player_for(_actor), _player)
	assert_eq(NpcFeedingQueries.minimum_health_fraction(_actor), 0.1)
	other.rules.clear()
	assert_null(NpcFeedingTargetQueries.wounded_player_for(_actor))
	assert_eq(NpcFeedingQueries.minimum_health_fraction(_actor), 0.0)
#endregion


#region Ordinary attacks and interruptions
func test_timer_melee_cost_stops_at_floor_and_native_branch_releases_combat_and_motion() -> void:
	_health.current = 40.0
	_start_attack()
	_world.process(0.5, "FeedingFixture")
	assert_eq(_health.current, 10.0)
	assert_false(_health.depleted)
	assert_false(_player.has_component(C_Death))
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_combat.phase, C_NpcCombat.Phase.READY)
	assert_eq((_actor.get_component(C_NpcIntent) as C_NpcIntent).speed_fraction, 1.0)
	assert_false((_actor.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert_false(NpcAttackService.start_against(_actor, _player, C_NpcCombat.Kind.MELEE, 0))


func test_queue_and_last_moment_health_change_cannot_make_ordinary_hits_lethal() -> void:
	_damage.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_health.current = 40.0
	assert_true(CombatService.hit(_actor, _actor, _player, 1000.0))
	assert_true(CombatService.hit(_actor, _actor, _player, 1000.0))
	assert_eq(_health.current, 40.0)
	_world.flush_command_buffers()
	assert_eq(_health.current, 10.0)
	assert_false(_health.depleted)
	_health.current = 40.0
	_start_attack()
	_health.current = 5.0
	_world.process(0.5, "FeedingFixture")
	assert_eq(_health.current, 5.0)
	assert_eq(_combat.phase, C_NpcCombat.Phase.READY)
	_step()
	assert_null(CombatQueries.target_for(_actor))


func test_projectile_collision_keeps_captured_floor_after_launcher_policy_changes() -> void:
	_health.current = 40.0
	var attack: DEF_NpcAttack = DEF_NpcAttack.new()
	attack.damage = 1000.0
	attack.projectile_speed = 10.0
	assert_true(ProjectileService.launch(_actor, _player, attack))
	var projectile: Entity = _world.query.with_all([C_CombatProjectile]).execute_one()
	assert_not_null(projectile)
	var state: C_CombatProjectile = (
		projectile.get_component(C_CombatProjectile) as C_CombatProjectile
	)
	assert_eq(state.minimum_health_fraction, 0.1)
	_person.profile = DEF_NpcArchetype.new()
	assert_eq(NpcFeedingQueries.minimum_health_fraction(_actor), 0.0)
	_world.process(0.2, "FeedingProjectile")
	assert_eq(_health.current, 10.0)
	assert_false(_player.has_component(C_Death))
	assert_null(_world.query.with_all([C_CombatProjectile]).execute_one())


func test_invalid_authored_feeding_cannot_start_commit_or_launch_an_ordinary_attack() -> void:
	_health.current = 40.0
	_person.profile = DEF_NpcArchetype.new()
	var rule: DEF_NpcFeeding = DEF_NpcFeeding.new()
	rule.minimum_health_fraction = 0.0
	_person.profile.rules = [rule]
	assert_false(rule.valid_configuration())
	assert_false(CombatService.hit(_actor, _actor, _player, 1000.0))
	assert_false(NpcAttackService.start_against(_actor, _player, C_NpcCombat.Kind.MELEE, 0))
	assert_false(ProjectileService.launch(_actor, _player, DEF_NpcAttack.new()))
	assert_eq(_health.current, 40.0)


func test_synchronous_reaction_reset_consumes_obsolete_start_without_rebinding_or_sensing() -> void:
	var observer: FeedingReceiverMutator = FeedingReceiverMutator.new()
	_world.add_observer(observer)
	_health.current = 60.0
	_sense()
	_step()
	assert_null(CombatQueries.target_for(_actor))
	assert_false(_awareness.target_visible)
	assert_false(_awareness.player_visible)
	assert_null(_actor.get_node_or_null("Brain"))


func test_reaction_retirement_stops_native_execution_before_later_actor_access() -> void:
	var observer: FeedingReceiverMutator = FeedingReceiverMutator.new()
	observer.retire = true
	_world.add_observer(observer)
	_health.current = 60.0
	_sense()
	var state: C_NpcAwareness = _awareness
	_step()
	assert_false(is_instance_valid(_actor))
	assert_false(state.target_visible)
	assert_eq(_health.current, 60.0)
#endregion
