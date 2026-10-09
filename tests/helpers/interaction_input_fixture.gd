extends RefCounted
## Test-only World execution of real interaction owners with one temporary query scope.
class_name InteractionInputFixture

const TARGET_GROUP: String = "interaction_input_fixture_target"
const OWNER_GROUP: String = "interaction_input_fixture_owner"

## Narrows only the production query, preserving actual input arbitration and command flushing.
class InputOwner extends S_InteractionInput:
	#region Fixture query
	func query() -> QueryBuilder:
		return super.query().with_group([InteractionInputFixture.TARGET_GROUP])
	#endregion

## Narrows only the production marker query.
class MarkerOwner extends S_Marker:
	#region Fixture query
	func query() -> QueryBuilder:
		return super.query().with_group([InteractionInputFixture.TARGET_GROUP])
	#endregion

## Narrows only the production decay query.
class DecayOwner extends S_ProlongedDecay:
	#region Fixture query
	func query() -> QueryBuilder:
		return super.query().with_group([InteractionInputFixture.TARGET_GROUP])
	#endregion

#region Actual scheduled steps
## Consumes the prepared C_Controller snapshot through native World process and command-buffer execution.
static func advance(actor: Entity, delta: float = 0.0) -> void:
	_run(InputOwner.new(), actor, delta)


## Advances actual marker continuation for the selected active tool.
static func marker(tool: Entity) -> void:
	for installed: System in ECS.world.systems:
		if installed is MarkerOwner:
			_run(installed, tool, 0.0)
			return
	_run(MarkerOwner.new(), tool, 0.0)


## Advances actual target idle decay independently of actor input.
static func decay(target: Entity, delta: float) -> void:
	_run(DecayOwner.new(), target, delta)


static func _run(owner: System, subject: Entity, delta: float) -> void:
	subject.add_to_group(TARGET_GROUP)
	owner.group = OWNER_GROUP + ("/marker" if owner is MarkerOwner else "/decay" if owner is DecayOwner else "/input")
	if owner not in ECS.world.systems:
		ECS.world.add_system(owner)
	ECS.world.process(delta, owner.group)
	# Marker teardown is a real session shutdown; retain this owner until fixture World teardown.
	if not owner is MarkerOwner:
		ECS.world.remove_system(owner)
	if is_instance_valid(subject):
		subject.remove_from_group(TARGET_GROUP)
#endregion
