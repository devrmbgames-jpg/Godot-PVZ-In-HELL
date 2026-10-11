extends GutTest
## Native artifact volumes, typed receiver precedence, committed resistance/healing and cadence.

const HOLY_SCENE: String = "res://content/domains/combat/entities/holy_artifact.tscn"
const UNHOLY_SCENE: String = "res://content/domains/combat/entities/unholy_artifact.tscn"

var _world: World = null
var _source: Entity = null
var _receivers: Array[Entity] = []
var _recorder: DamageRecorder = null
var _system: S_ReceiverEffect = null


class DamageRecorder extends Observer:
	## Committed damage/heal receipts retained only by the fixture.
	var results: Array[DamageResult] = []


	#region Terminal facts
	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		results.append(payload as DamageResult)
	#endregion


#region Native physical fixtures
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_GrabLifecycle.new())
	_system = S_ReceiverEffect.new()
	_world.add_system(_system)
	_recorder = DamageRecorder.new()
	_world.add_observer(_recorder)
	_receivers.clear()
	for value: float in [-40.0, 0.0, 40.0]:
		var karma: C_Karma = C_Karma.new()
		karma.value = value
		var target: Entity = _receiver([karma])
		_receivers.append(target)
	var tags: C_ReceiverTraits = C_ReceiverTraits.new()
	tags.traits = C_ReceiverTraits.Trait.HOLY_VULNERABLE | C_ReceiverTraits.Trait.UNHOLY_HEALING
	_receivers.append(_receiver([tags]))


func _receiver(capabilities: Array[Component]) -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_RigidBodyCharacter)
	body.freeze = true
	body.collision_layer = 16
	var target: Entity = body as Node as Entity
	var health: C_Health = C_Health.new()
	health.value = 100.0
	health.current = 60.0
	target.component_resources = [health]
	target.component_resources.append_array(capabilities)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.2
	shape.shape = sphere
	body.add_child(shape)
	_world.add_entity(target)
	body.global_position = Vector3(float(_receivers.size()) * 0.6 - 0.9, 0.0, 1.0)
	return target


func _spawn(path: String) -> void:
	_source = (load(path) as PackedScene).instantiate() as Entity
	EntityCompositionFixture.register(_world, _source)
	var body: RigidBody3D = _source as Node as RigidBody3D
	body.freeze = true
	assert_not_null(_source.get_component(C_Grabbable))
	assert_false(_source.has_component(C_Package))
	var catalog: C_InventoryItem = _source.get_component(C_InventoryItem) as C_InventoryItem
	assert_true(catalog.definition.requires_world_body())
	assert_eq(catalog.definition.categories, DEF_InventoryItem.Category.ARTIFACT)
	var area: Area3D = _source.get_node("EffectArea") as Area3D
	var settled: bool = false
	for frame: int in 10:
		await get_tree().physics_frame
		await get_tree().process_frame
		settled = true
		for receiver: Entity in _receivers:
			if not area.overlaps_body(receiver as Node as PhysicsBody3D):
				settled = false
		if settled:
			break
	assert_true(settled, "All receivers entered the actual Jolt Area3D")


func _health(index: int) -> float:
	return (_receivers[index].get_component(C_Health) as C_Health).current


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_receivers.clear()
	_source = null
	_recorder = null
	_system = null
#endregion


#region Native periodic effects
func test_holy_area_uses_karma_resistance_and_one_receipt_per_interval() -> void:
	await _spawn(HOLY_SCENE)
	var resistance: C_DamageResistance = C_DamageResistance.new()
	resistance.multipliers[DamageRequest.Type.HOLY] = 0.5
	_receivers[3].add_component(resistance)
	_world.process(0.5)
	assert_true(_recorder.results.is_empty())
	_world.process(0.5)
	assert_eq(_health(0), 52.0)
	assert_eq(_health(1), 60.0)
	assert_eq(_health(2), 60.0)
	assert_eq(_health(3), 56.0)
	assert_eq(_recorder.results.size(), 2)
	for result: DamageResult in _recorder.results:
		assert_eq(result.request.source, _source)
		assert_eq(result.request.damage_type, DamageRequest.Type.HOLY)
		assert_eq(result.request.operation, DamageRequest.Operation.DAMAGE)
	_world.process(2.0)
	assert_eq(_health(0), 36.0)
	assert_eq(_health(3), 48.0)
	assert_eq(_recorder.results.size(), 4, "Due intervals coalesce into one receipt per target")


func test_unholy_area_heals_tagged_creature_but_only_damages_high_player() -> void:
	await _spawn(UNHOLY_SCENE)
	var resistance: C_DamageResistance = C_DamageResistance.new()
	resistance.multipliers[DamageRequest.Type.UNHOLY] = 0.0
	_receivers[3].add_component(resistance)
	_world.process(1.0)
	assert_eq(_health(0), 60.0)
	assert_eq(_health(1), 60.0)
	assert_eq(_health(2), 52.0)
	assert_eq(_health(3), 68.0, "Healing ignores damage immunity")
	assert_eq(_recorder.results.size(), 2)
	for result: DamageResult in _recorder.results:
		assert_eq(result.request.source, _source)
		assert_eq(result.request.damage_type, DamageRequest.Type.UNHOLY)
		assert_eq(
			result.request.operation,
			(
				DamageRequest.Operation.HEAL
				if result.request.target == _receivers[3]
				else DamageRequest.Operation.DAMAGE
			),
		)
	_world.process(5.0)
	assert_eq(_health(3), 100.0, "Healing remains capped by O_Damage")


func test_player_thresholds_override_creature_tags_and_leave_boundaries_neutral() -> void:
	await _spawn(HOLY_SCENE)
	var tags: C_ReceiverTraits = C_ReceiverTraits.new()
	tags.traits = C_ReceiverTraits.Trait.HOLY_VULNERABLE | C_ReceiverTraits.Trait.UNHOLY_HEALING
	_receivers[1].add_component(tags)
	assert_eq(
		ReceiverEffectRules.operation_for(_receivers[1], DEF_ReceiverEffect.Alignment.HOLY),
		ReceiverEffectRules.EXCLUDED,
	)
	assert_eq(
		ReceiverEffectRules.operation_for(_receivers[1], DEF_ReceiverEffect.Alignment.UNHOLY),
		ReceiverEffectRules.EXCLUDED,
	)
	assert_true(KarmaService.set_value(_receivers[0], -25.0))
	assert_true(KarmaService.set_value(_receivers[2], 25.0))
	_world.process(1.0)
	assert_eq(_health(0), 60.0)
	assert_eq(_health(1), 60.0)
	assert_eq(_health(2), 60.0)
	assert_eq(_recorder.results.size(), 1)


func test_source_veto_blocks_harm_and_preserves_committed_result_path() -> void:
	await _spawn(HOLY_SCENE)
	_source.add_component(C_NoDamage.new())
	_world.process(1.0)
	assert_eq(_health(0), 60.0)
	assert_eq(_health(3), 60.0)
	assert_eq(_recorder.results.size(), 2)
	for result: DamageResult in _recorder.results:
		assert_eq(result.outcome, DamageResult.Outcome.BLOCKED)
		assert_eq(result.reason, &"source_veto")


func test_native_pickup_and_throw_keep_physical_source_and_actor_attribution() -> void:
	await _spawn(HOLY_SCENE)
	var holder: E_RigidBodyCharacter = _receivers[0] as E_RigidBodyCharacter
	for component: Component in [
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Interactor.new(),
		C_Controller.new(),
	]:
		holder.add_component(component)
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0.9, 0.0, -1.0)
	holder.add_child(anchor)
	holder.right_hand_slot = anchor
	var ray: RayCast3D = RayCast3D.new()
	ray.collision_mask = 10
	holder.add_child(ray)
	holder.interaction_ray_cast = ray
	ray.global_position = (_source as Node as Node3D).global_position + Vector3.BACK
	ray.target_position = Vector3.FORWARD * 3.0
	ray.force_raycast_update()
	assert_eq(ray.get_collider(), _source)
	(_source as Node as RigidBody3D).freeze = false
	assert_true(GrabService.try_pickup(holder, _source, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_not_null(GrabQueries.held_relationship(_source))
	_world.process(1.0)
	assert_eq(_recorder.results.size(), 2, "The low-karma holder receives one aura hit")
	for result: DamageResult in _recorder.results:
		assert_eq(result.request.source, _source)
		assert_eq(result.request.instigator, holder)
	(holder.get_component(C_Controller) as C_Controller).direction_look = Vector3.FORWARD
	GrabService.throw(holder, _source)
	assert_null(GrabQueries.held_relationship(_source))
	assert_not_null(ThrowContext.relationship(_source))
	assert_false((_source as Node as RigidBody3D).freeze)
	_world.process(1.0)
	assert_eq(_recorder.results.size(), 4)
	for result: DamageResult in _recorder.results:
		assert_eq(result.request.source, _source)
		assert_eq(result.request.instigator_id, holder.id)


func test_queued_source_retirement_drops_pending_effect_without_health_change() -> void:
	await _spawn(HOLY_SCENE)
	_system.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.process(1.0)
	assert_true(_recorder.results.is_empty())
	_world.remove_entity(_source)
	_world.flush_command_buffers()
	assert_true(_recorder.results.is_empty())
	assert_eq(_health(0), 60.0)
	assert_eq(_health(3), 60.0)
	_source = null


func test_disabled_source_and_invalid_tuning_do_not_dispatch() -> void:
	await _spawn(HOLY_SCENE)
	_source.enabled = false
	_world.process(1.0)
	assert_true(_recorder.results.is_empty())
	_source.enabled = true
	var state: C_ReceiverEffect = _source.get_component(C_ReceiverEffect) as C_ReceiverEffect
	state.definition = state.definition.duplicate() as DEF_ReceiverEffect
	state.definition.tick_seconds = 0.0
	_world.process(1.0)
	assert_true(_recorder.results.is_empty())
	state.definition.tick_seconds = 1.0
	state.definition.amount_per_tick = NAN
	_world.process(1.0)
	assert_true(_recorder.results.is_empty())
#endregion
