extends RefCounted
## Explicit nonphysical projectile construction; flight belongs to S_CombatProjectile.
class_name ProjectileService

const PROJECTILE_SCENE: PackedScene = preload(
	"res://content/domains/combat/entities/combat_projectile.tscn")

#region Launch construction
## Prepares velocity/damage/attribution/source before one compiled native registration.
static func launch(actor: Entity, target: Entity, attack: DEF_NpcAttack) -> bool:
	if not GrabQueries.holder_available(actor) or not GrabQueries.holder_available(target) \
			or not is_instance_valid(ECS.world):
		return false

	var projectile: Entity = PROJECTILE_SCENE.instantiate() as Entity
	var recipes: Array[Component] = projectile.component_resources.duplicate()
	var state: C_CombatProjectile = null
	for recipe_index: int in recipes.size():
		if recipes[recipe_index] is C_CombatProjectile:
			state = EntityRecipeRules.copy_component(recipes[recipe_index]) as C_CombatProjectile
			recipes[recipe_index] = state
			break
	if state == null:
		projectile.free()
		return false
	if actor.has_component(C_NoDamage):
		recipes.append(C_NoDamage.new())

	var origin: Vector3 = CombatGeometry.origin(actor)
	state.velocity = origin.direction_to(CombatGeometry.aim_point(target)) * attack.projectile_speed
	state.remaining_seconds = attack.projectile_lifetime
	state.damage = attack.damage * HungerRules.damage_multiplier(
		actor.get_component(C_Hunger) as C_Hunger)
	state.collision_mask = attack.collision_mask
	var request: DamageRequest = DamageRequest.new()
	request.instigator = actor
	request.source = actor
	request.target = target
	request.damage_type = DamageRequest.Type.PROJECTILE
	state.attribution = CombatAttribution.describe(request)
	state.instigator_id = actor.id
	projectile.component_resources = recipes

	# Initial pose is owned by this construction boundary; no flight tick has run yet.
	ECS.world.add_child(projectile)
	(projectile as Node as Node3D).global_position = origin
	var context: EntitySpawnContext = EntityCompositionService.context_for(projectile, ECS.world,
		projectile.id if not projectile.id.is_empty() else GECSIO.uuid())
	context.bindings[&"source"] = actor
	var source_intent: EntityInitialBinding = EntityInitialBinding.new()
	source_intent.relation = R_ProjectileSource.new()
	source_intent.endpoint = &"source"
	context.initial_bindings = [source_intent]
	if not EntityCompositionService.try_register(context, false):
		projectile.free()
		return false
	return true
#endregion
