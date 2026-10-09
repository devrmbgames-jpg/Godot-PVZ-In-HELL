extends RefCounted
## Test-only native World execution of real physical interaction owners with one temporary target filter.
class_name InteractionPhysicsFixture

const TARGET_GROUP: String = "interaction_physics_fixture_target"
const OWNER_GROUP: String = "interaction_physics_fixture_owner"

## Narrows only the production anchor-rest query.
class AnchorOwner extends S_AnchorStability:
	#region Fixture query
	func query() -> QueryBuilder:
		return super.query().with_group([InteractionPhysicsFixture.TARGET_GROUP])
	#endregion

#region Actual owner execution
## Advances real scheduled physical rest for the selected authored target.
static func anchor(target: Entity, delta: float) -> void:
	target.add_to_group(TARGET_GROUP)
	var owner: AnchorOwner = AnchorOwner.new()
	owner.group = OWNER_GROUP
	ECS.world.add_system(owner)
	ECS.world.process(delta, OWNER_GROUP)
	if is_instance_valid(target):
		target.remove_from_group(TARGET_GROUP)
	ECS.world.remove_system(owner)
#endregion
