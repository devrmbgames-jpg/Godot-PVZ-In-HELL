extends GutTest
## Proves dormant registered actors remain indexed through component and relationship lifecycle changes.

class FixtureWorld extends GameWorld:
	# Isolate the production registration API from authored level startup.
	func _ready() -> void:
		initialize()

var _world: GameWorld
var _disabled_events: int = 0
var _added_events: int = 0

#region Isolated production World
## Uses GameWorld's actual disabled lifecycle without constructing gameplay or a save slot.
func before_each() -> void:
	_world = FixtureWorld.new()
	add_child(_world)
	ECS.world = _world
	_disabled_events = 0
	_added_events = 0
	_world.entity_disabled.connect(_on_disabled)
	_world.component_added.connect(_on_added)


## Frees the registered fixture and clears the global World reference.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _entity(components: Array[Component]) -> Entity:
	var subject: Entity = Entity.new()
	subject.component_resources = components
	_world.add_entity(subject)
	return subject


func _on_disabled(_subject: Entity) -> void:
	_disabled_events += 1


func _on_added(_subject: Entity, _component: Variant) -> void:
	_added_events += 1
#endregion

#region Dormant registered structure
## Matches the restore regression: a disabled NPC loses its service role before later reactivation.
func test_disabled_component_removal_and_replacement_keep_queries_current() -> void:
	var subject: Entity = _entity([C_Challenge.new(), C_CustomerAgent.new()])
	_world.disable_entity(subject)
	assert_false(subject.enabled)
	assert_false(subject.is_processing())
	assert_false(subject.is_physics_processing())
	assert_eq(_disabled_events, 1, "Native disable facts still reach lifecycle observers")

	subject.remove_component(C_CustomerAgent)
	assert_eq(_world.query.with_all([C_Challenge, C_CustomerAgent]).execute().size(), 0)
	subject.add_component(C_CustomerAgent.new())
	assert_eq(_world.query.with_all([C_Challenge, C_CustomerAgent]).execute(), [subject])
	assert_false(subject.enabled, "Updating the native index must not reactivate the actor")
	_world.enable_entity(subject)
	assert_true(subject.enabled)
	assert_eq(_world.query.with_all([C_Challenge, C_CustomerAgent]).execute(), [subject])


## Both per-link and batched operations maintain structural relationship query membership while dormant.
func test_disabled_relationship_changes_keep_native_index_current() -> void:
	var subject: Entity = _entity([])
	var endpoint: Entity = _entity([])
	var link: Relationship = Relationship.new(R_NpcMoveTarget.new(), endpoint)
	_world.disable_entity(subject)
	subject.add_relationship(link)
	assert_eq(_world.query.with_relationship([link]).execute(), [subject])
	subject.remove_relationship(link)
	assert_eq(_world.query.with_relationship([link]).execute().size(), 0)

	var other_endpoint: Entity = _entity([])
	var other_link: Relationship = Relationship.new(R_NpcMoveTarget.new(), other_endpoint)
	subject.add_relationships([link, other_link])
	assert_eq(_world.query.with_relationship([link, other_link]).execute(), [subject])
	subject.remove_relationships([link, other_link])
	assert_eq(_world.query.with_relationship([link]).execute().size(), 0)
	assert_eq(_world.query.with_relationship([other_link]).execute().size(), 0)
	assert_false(subject.enabled)


## Repeated disable/enable cannot duplicate the World's signal subscriptions or published component facts.
func test_repeated_participation_changes_do_not_duplicate_tracking() -> void:
	var subject: Entity = _entity([])
	_world.disable_entity(subject)
	_world.disable_entity(subject)
	_world.enable_entity(subject)
	_world.disable_entity(subject)
	_added_events = 0
	subject.add_component(C_CustomerAgent.new())
	assert_eq(_added_events, 1)
	assert_eq(_disabled_events, 3)
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute(), [subject])
	_world.enable_entity(subject)
	subject.add_component(C_Challenge.new())
	assert_eq(_added_events, 2)
	assert_eq(_world.query.with_all([C_Challenge, C_CustomerAgent]).execute(), [subject])
#endregion
