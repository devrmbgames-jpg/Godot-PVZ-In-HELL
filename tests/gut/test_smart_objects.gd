extends GutTest
## Real GECS contention, lifetime and compiler acceptance for transient Smart Object reservations.


## Deterministic executor boundary; production package execution is covered by return integration.
class Executor extends DEF_InteractionAction:
	## Availability can change after enqueue to exercise commit-time eligibility.
	var eligible: bool = true
	## Explicit effect failure must never publish success or retain the slot.
	var succeeds: bool = true
	## Count of actual effects, independent of discovery/acquisition.
	var executions: int = 0


	#region Deterministic effect
	func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		return eligible


	func complete(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		executions += 1
		return succeeds
	#endregion


var _world: World = null
var _observer: O_SmartObject = null
var _actor: Entity = null
var _object: Entity = null


#region Real owner fixture
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_observer = O_SmartObject.new()
	_world.add_observer(_observer)
	_actor = _new_actor()
	_object = _new_object()


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _new_actor(stable_id: String = "") -> Entity:
	var actor: Entity = E_TraitedEntity.new()
	actor.id = stable_id
	actor.component_resources = [C_GrabControl.new()]
	_world.add_entity(actor)
	return actor


func _new_object(stable_id: String = "") -> Entity:
	var object: Entity = E_TraitedEntity.new()
	object.id = stable_id
	var marker: Marker3D = Marker3D.new()
	marker.name = "ServiceMarker"
	object.add_child(marker)
	var service_slot: DEF_SmartSlot = DEF_SmartSlot.new()
	service_slot.slot_id = &"service"
	service_slot.marker = NodePath("ServiceMarker")
	var affordance: DEF_SmartAffordance = DEF_SmartAffordance.new()
	affordance.affordance_id = &"service"
	affordance.slot_id = &"service"
	affordance.executor = Executor.new()
	affordance.required_actor_components = [C_GrabControl]
	var definition: DEF_SmartObject = DEF_SmartObject.new()
	definition.slots = [service_slot]
	definition.affordances = [affordance]
	var recipe: C_SmartObject = C_SmartObject.new()
	recipe.definition = definition
	object.component_resources = [recipe]
	_world.add_entity(object)
	return object


func _executor() -> Executor:
	return (
		(_object.get_component(C_SmartObject) as C_SmartObject).definition.affordances[0].executor
	) as Executor


func _submit(
	operation: SmartObjectRequest.Operation,
	token: StringName = &"",
) -> SmartObjectReceipt:
	return SmartObjectService.submit(operation, _actor, _object, &"service", token)
#endregion


#region Atomic contention and actual outcomes
## Two queued contenders remain pending until exactly one relation has been committed.
func test_two_queued_contenders_have_one_committed_winner() -> void:
	_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var contender: Entity = _new_actor()
	var first: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	var second: SmartObjectReceipt = SmartObjectService.submit(
		SmartObjectRequest.Operation.ACQUIRE,
		contender,
		_object,
		&"service",
	)
	assert_eq(first.status, SmartObjectReceipt.Status.PENDING)
	assert_eq(second.status, SmartObjectReceipt.Status.PENDING)
	assert_true(_actor.relationships.is_empty())
	_world.flush_command_buffers()
	assert_eq(first.status, SmartObjectReceipt.Status.ACQUIRED)
	assert_eq(second.status, SmartObjectReceipt.Status.REJECTED)
	assert_eq(second.reason, &"occupied")
	assert_eq(_actor.relationships.size(), 1)
	assert_true(contender.relationships.is_empty())
	assert_false(first.token.is_empty())
	assert_eq(_executor().executions, 0)


## Eligibility is checked at commit rather than captured as a premature success.
func test_eligibility_change_after_enqueue_rejects_without_reservation() -> void:
	_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var receipt: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.USE)
	_executor().eligible = false
	_world.flush_command_buffers()
	assert_eq(receipt.status, SmartObjectReceipt.Status.REJECTED)
	assert_eq(receipt.reason, &"ineligible")
	assert_true(_actor.relationships.is_empty())
	assert_eq(_executor().executions, 0)


## A failed executor retires its acquired slot and allows a later valid use.
func test_failed_execute_has_no_success_or_leaked_reservation() -> void:
	_executor().succeeds = false
	var failed: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.USE)
	assert_eq(failed.status, SmartObjectReceipt.Status.REJECTED)
	assert_eq(failed.reason, &"executor_rejected")
	assert_true(_actor.relationships.is_empty())
	_executor().succeeds = true
	var succeeded: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.USE)
	assert_eq(succeeded.status, SmartObjectReceipt.Status.SUCCEEDED)
	assert_eq(_executor().executions, 2)
	assert_true(_actor.relationships.is_empty())


## Repeated callbacks cannot use or cancel a replacement acquisition on the same object.
func test_stale_token_cannot_cancel_or_execute_new_reservation() -> void:
	var first: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	assert_eq(
		_submit(SmartObjectRequest.Operation.CANCEL, first.token).status,
		SmartObjectReceipt.Status.CANCELLED,
	)
	var replacement: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	assert_ne(first.token, replacement.token)
	assert_eq(_submit(SmartObjectRequest.Operation.CANCEL, first.token).reason, &"stale_token")
	assert_eq(_submit(SmartObjectRequest.Operation.EXECUTE, first.token).reason, &"stale_token")
	assert_eq(_actor.relationships.size(), 1)
	assert_eq(_executor().executions, 0)
	assert_eq(
		_submit(SmartObjectRequest.Operation.EXECUTE, replacement.token).status,
		SmartObjectReceipt.Status.SUCCEEDED,
	)
	assert_true(_actor.relationships.is_empty())


## Marker loss after acquisition rejects execution and retires precisely that reservation.
func test_lost_marker_rejects_execution_without_leaking_slot() -> void:
	var acquired: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	_object.get_node("ServiceMarker").free()
	var receipt: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.EXECUTE, acquired.token)
	assert_eq(receipt.reason, &"ineligible")
	assert_true(_actor.relationships.is_empty())
	assert_eq(_executor().executions, 0)
#endregion


#region Incarnation and lifetime boundaries
## Target removal retires incoming relationships; an old queued Node cannot match its replacement.
func test_removed_recreated_object_rejects_queued_request_and_old_token() -> void:
	var acquired: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	var stable_id: String = _object.id
	_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var queued: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.EXECUTE, acquired.token)
	_world.remove_entity(_object)
	assert_true(_actor.relationships.is_empty())
	_object = _new_object(stable_id)
	_world.flush_command_buffers()
	assert_eq(queued.status, SmartObjectReceipt.Status.REJECTED)
	var replacement: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	_world.flush_command_buffers()
	assert_eq(replacement.status, SmartObjectReceipt.Status.ACQUIRED)
	var late: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.CANCEL, acquired.token)
	_world.flush_command_buffers()
	assert_eq(late.reason, &"stale_token")
	assert_eq(_actor.relationships.size(), 1)


## Replacing capability data within the same Node invalidates the captured queued incarnation.
func test_component_replacement_rejects_old_queued_incarnation() -> void:
	_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var pending: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	var previous: C_SmartObject = _object.get_component(C_SmartObject) as C_SmartObject
	_object.remove_component(previous)
	var replacement: C_SmartObject = C_SmartObject.new()
	replacement.definition = previous.definition
	_object.add_component(replacement)
	_world.flush_command_buffers()
	assert_eq(pending.reason, &"incarnation_replaced")
	assert_true(_actor.relationships.is_empty())


## A pre-load World's late command cannot release a new World's slot with the same stable IDs.
func test_world_replacement_rejects_old_queue_and_token() -> void:
	var acquired: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var pending: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.CANCEL, acquired.token)
	var old_world: World = _world
	var actor_id: String = _actor.id
	var object_id: String = _object.id
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_observer = O_SmartObject.new()
	_world.add_observer(_observer)
	_actor = _new_actor(actor_id)
	_object = _new_object(object_id)
	var current: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	old_world.flush_command_buffers()
	assert_eq(pending.reason, &"world_replaced")
	assert_eq(current.status, SmartObjectReceipt.Status.ACQUIRED)
	assert_ne(acquired.token, current.token)
	assert_eq(_actor.relationships.size(), 1)
	assert_eq(_submit(SmartObjectRequest.Operation.CANCEL, acquired.token).reason, &"stale_token")
	assert_eq(_actor.relationships.size(), 1)
	old_world.purge(false)
	old_world.free()


## Death, disabling and capability loss retire live reservations without an occupancy cache.
func test_lifecycle_retirement_is_immediate_and_idempotent() -> void:
	_submit(SmartObjectRequest.Operation.ACQUIRE)
	_actor.add_component(C_Death.new())
	assert_true(_actor.relationships.is_empty())
	assert_false(SmartObjectService.is_available(_actor, _object, &"service"))
	_actor.remove_component(C_Death)
	_submit(SmartObjectRequest.Operation.ACQUIRE)
	_world.disable_entity(_object)
	assert_true(_actor.relationships.is_empty())
	SmartObjectService.entity_unavailable(_object, _world)
	assert_true(_actor.relationships.is_empty())
#endregion


#region Required capability and exclusive slot enforcement
## SceneTree target loss immediately frees its slot and breaks the derived callback cycle.
func test_tree_exit_retires_exact_binding_and_detaches_engine_hooks() -> void:
	var acquired: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	var binding: Relationship = _actor.relationships[0]
	var data: R_SmartObjectReservation = binding.relation as R_SmartObjectReservation
	var callback: Callable = data.retirement_callback
	var parent: Node = _object.get_parent()
	parent.remove_child(_object)
	assert_true(_actor.relationships.is_empty())
	assert_false(data.retirement_callback.is_valid())
	assert_false(_actor.tree_exiting.is_connected(callback))
	assert_false(_object.tree_exiting.is_connected(callback))
	parent.add_child(_object)
	var current: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	assert_ne(acquired.token, current.token)
	assert_eq(_submit(SmartObjectRequest.Operation.CANCEL, acquired.token).reason, &"stale_token")
	assert_eq(_actor.relationships.size(), 1)


## In-place restore leaves Nodes/World intact but terminates every pre-load token and receipt.
func test_same_world_restore_boundary_retires_old_receipts_and_tokens() -> void:
	var acquired: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var pending: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.EXECUTE, acquired.token)
	var activity: Dictionary[Observer, bool] = SnapshotRestoreBoundary.begin(_world)
	assert_eq(pending.status, SmartObjectReceipt.Status.REJECTED)
	assert_eq(pending.reason, &"world_reconstructed")
	assert_true(_actor.relationships.is_empty())
	SnapshotRestoreBoundary.finish(_world, activity)
	_world.flush_command_buffers()
	assert_eq(_executor().executions, 0)
	var current: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	_world.flush_command_buffers()
	assert_ne(acquired.token, current.token)
	var late: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.CANCEL, acquired.token)
	_world.flush_command_buffers()
	assert_eq(late.reason, &"stale_token")
	assert_eq(_actor.relationships.size(), 1)


## Losing a required actor capability immediately retires the live binding.
func test_actor_capability_loss_retires_reservation() -> void:
	var acquired: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
	assert_eq(acquired.status, SmartObjectReceipt.Status.ACQUIRED)
	_actor.remove_component(C_GrabControl)
	assert_true(_actor.relationships.is_empty())
	assert_false(SmartObjectService.is_available(_actor, _object, &"service"))


## A conflicting external binding cannot bypass the slot check on execute or cancel.
func test_execute_and_cancel_check_exclusive_slot_ownership() -> void:
	for operation: SmartObjectRequest.Operation in [
		SmartObjectRequest.Operation.EXECUTE,
		SmartObjectRequest.Operation.CANCEL,
	]:
		var acquired: SmartObjectReceipt = _submit(SmartObjectRequest.Operation.ACQUIRE)
		var contender: Entity = _new_actor()
		var conflict: R_SmartObjectReservation = R_SmartObjectReservation.new()
		conflict.slot_id = &"service"
		var binding: Relationship = Relationship.new(conflict, _object)
		contender.add_relationship(binding)
		var receipt: SmartObjectReceipt = _submit(operation, acquired.token)
		assert_eq(receipt.reason, &"slot_conflict")
		assert_true(_actor.relationships.is_empty())
		assert_eq(contender.relationships.size(), 1)
		contender.remove_relationship(binding)
	assert_eq(_executor().executions, 0)
#endregion


#region Shared authored provider acceptance
## Both native return points retain physical structure and use the same executor/schema.
func test_two_native_variants_compile_same_smart_object_capability() -> void:
	for scene_path: String in [
		"res://content/domains/packages/entities/package_return_point.tscn",
		"res://content/domains/packages/entities/package_return_point_wall.tscn",
	]:
		var prefab: PackedScene = load(scene_path) as PackedScene
		var actor: Entity = autofree(prefab.instantiate()) as Entity
		var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(actor)
		assert_true(report.valid, JSON.stringify(report))
		assert_not_null(actor.get_node("ReturnMarker") as Marker3D)
		assert_not_null(actor.get_node("Collision") as CollisionShape3D)
		assert_not_null(actor.get_node("Mesh") as MeshInstance3D)
		EntityCompositionFixture.register(_world, actor)
		var data: C_SmartObject = actor.get_component(C_SmartObject) as C_SmartObject
		assert_not_null(data)
		assert_true(data.definition.affordances[0].executor is DEF_PackageReturnAction)
		var actions_recipe: Component = actor.get_component(C_InteractionActionSet)
		var actions: C_InteractionActionSet = actions_recipe as C_InteractionActionSet
		assert_eq(actions.actions.size(), 1)
		assert_true(actions.actions[0] is DEF_SmartObjectAction)
		assert_false(actions.actions[0].is_available(_actor, actor, actor))


## Compiler and Inspector/headless provider reject each missing authored contract input.
func test_schema_errors_are_reported_by_common_compiler_provider() -> void:
	var prefab: PackedScene = load(
		"res://content/domains/packages/entities/package_return_point.tscn"
	) as PackedScene
	var actor: Entity = autofree(prefab.instantiate()) as Entity
	var authoring: E_TraitedEntity = actor as E_TraitedEntity
	authoring.traits = [authoring.traits[0].duplicate(true) as EntityTrait]
	var capability: ET_SmartObject = authoring.traits[0] as ET_SmartObject
	capability.definition.affordances[0].executor = null
	capability.definition.affordances[0].slot_id = &"missing"
	actor.get_node("ReturnMarker").free()
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(actor)
	assert_false(report.valid)
	var messages: String = JSON.stringify(report.actors)
	assert_string_contains(messages, "concrete executor")
	assert_string_contains(messages, "missing slot")
	assert_string_contains(messages, "Marker3D")
#endregion
