extends GutTest
## Retirement transfers destruction to GECS for registered Nodes, including detached actors.

var _world: World


#region Isolated native lifetime
## Establishes one real World without scheduled gameplay.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world


## Releases remaining native registrations and the owning World.
func after_each() -> void:
	_world.purge(false)
	ECS.world = null
	_world.free()
	await get_tree().process_frame


func _actor(in_tree: bool) -> Entity:
	var actor: Entity = Entity.new()
	actor.component_resources = [C_RemoveOnHealthDepleted.new()]
	_world.add_entity(actor, null, in_tree)
	return actor
#endregion


#region Registered and detached destruction
## Native removal immediately frees an actor outside the tree; retire must not touch it again.
func test_hazard_retirement_of_registered_detached_actor() -> void:
	var actor: Entity = _actor(false)
	var retired: WeakRef = weakref(actor)
	HazardLifecycle.retire(actor, _world)
	assert_null(retired.get_ref())
	assert_true(_world.entities.is_empty())


## Depletion intentionally rejects detached actors rather than invoking its destruction path.
func test_depletion_retirement_rejects_detached_actor() -> void:
	var actor: Entity = _actor(false)
	var retired: WeakRef = weakref(actor)
	var policy: C_RemoveOnHealthDepleted = actor.get_component(C_RemoveOnHealthDepleted) \
			as C_RemoveOnHealthDepleted
	var observer: O_RemoveOnHealthDepleted = O_RemoveOnHealthDepleted.new()
	_world.add_observer(observer)
	observer.call("_remove", retired, policy)
	assert_same(retired.get_ref(), actor)
	assert_true(_world.entities.has(actor))
	_world.remove_entity(actor)
	assert_null(retired.get_ref())
	assert_true(_world.entities.is_empty())


## Tree-owned actors are queued once and repeated retirement before deletion is harmless.
func test_hazard_retirement_of_tree_owned_actor_is_idempotent() -> void:
	var actor: Entity = _actor(true)
	var retired: WeakRef = weakref(actor)
	HazardLifecycle.retire(actor, _world)
	HazardLifecycle.retire(actor, _world)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(retired.get_ref())
	assert_true(_world.entities.is_empty())


## An unregistered Node remains owned by the caller and still needs queued destruction.
func test_hazard_retirement_of_unregistered_actor() -> void:
	var actor: Entity = Entity.new()
	var retired: WeakRef = weakref(actor)
	HazardLifecycle.retire(actor, _world)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(retired.get_ref())
#endregion
