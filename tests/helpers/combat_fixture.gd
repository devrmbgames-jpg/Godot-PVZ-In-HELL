extends RefCounted
## Test-only scoped World execution of real combat owners, with explicit command-driven NPC selection.
class_name CombatFixture

## Temporary target group restricts clock-focused tests to their selected actor/projectile.
const TARGET_GROUP: String = "combat_fixture_target"
## Temporary owner group excludes unrelated gameplay scheduling from focused assertions.
const OWNER_GROUP: String = "combat_fixture_owner"

## Uses the real player clock/scan with only a test query filter.
class MeleeOwner extends S_PlayerMelee:
	#region Fixture query
	## Restricts the production query to the selected fixture actor.
	func query() -> QueryBuilder:
		return super.query().with_group([CombatFixture.TARGET_GROUP])
	#endregion

## Uses the real NPC clock with only a test query filter.
class NpcOwner extends S_NpcCombat:
	#region Fixture query
	## Restricts the production query to the selected fixture actor.
	func query() -> QueryBuilder:
		return super.query().with_group([CombatFixture.TARGET_GROUP])
	#endregion

## Uses the real flight/collision owner with only a test query filter.
class ProjectileOwner extends S_CombatProjectile:
	#region Fixture query
	## Restricts the production query to the selected live projectile.
	func query() -> QueryBuilder:
		return super.query().with_group([CombatFixture.TARGET_GROUP])
	#endregion

## Uses the real isolated-customer owner with only a test query filter.
class CustomerOwner extends S_CustomerCombat:
	#region Fixture query
	## Restricts the production query to the selected fixture customer.
	func query() -> QueryBuilder:
		return super.query().with_group([CombatFixture.TARGET_GROUP])
	#endregion

#region Real owner execution
## Advances the real strike clock/scan/cancellation after the test explicitly started the strike.
static func melee(actor: Entity, delta: float) -> void:
	_run(MeleeOwner.new(), actor, delta)


## Advances an explicitly selected NPC attack; tests own selection rather than the auto selector.
static func npc(actor: Entity, delta: float) -> void:
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	var automatic: bool = state.automatic_attack_selection
	state.automatic_attack_selection = false
	_run(NpcOwner.new(), actor, delta)
	if is_instance_valid(actor) and actor.get_component(C_NpcCombat) == state:
		state.automatic_attack_selection = automatic


## Advances one real projectile flight step, including damage and actual World retirement.
static func projectile(subject: Entity, delta: float) -> void:
	_run(ProjectileOwner.new(), subject, delta)


## Runs actual isolated-customer escalation without advancing unrelated attack clocks.
static func customer(subject: Entity) -> void:
	_run(CustomerOwner.new(), subject, 0.0)
#endregion

#region Scoped World group
static func _run(owner: System, subject: Entity, delta: float) -> void:
	subject.add_to_group(TARGET_GROUP)
	owner.group = OWNER_GROUP
	ECS.world.add_system(owner)
	ECS.world.process(delta, OWNER_GROUP)
	if is_instance_valid(subject):
		subject.remove_from_group(TARGET_GROUP)
	ECS.world.remove_system(owner)
#endregion
