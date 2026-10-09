extends RefCounted
## Binds Customer cleanup to native NPC lifecycle; no scheduled behavior or second role authority.
class_name CustomerNpcLifecycleBinding

## Higher-owned native tree composition preserves Customer service priority and generic NPC branches.
const TREE_PATH: String = "res://content/domains/customers/ai/trees/bt_district_npc.tres"

#region Native lifecycle subscription
## Installs one role handler; native signals remain synchronous while World observers are suspended.
static func bind(body: E_DistrictNpc, world: World) -> void:
	# Repeated composition must reuse the existing binding, rather than compare newly created WeakRefs.
	for connection: Dictionary in body.role_cleanup_requested.get_connections():
		var existing: Callable = connection["callable"]
		if existing.get_method() != &"_on_cleanup" or existing.get_object() != (CustomerNpcLifecycleBinding as Script):
			continue
		var arguments: Array = existing.get_bound_arguments()
		var bound_world: WeakRef = arguments[1] as WeakRef
		if bound_world.get_ref() == world:
			return

	# A native connection owns the binding lifetime; witnesses retain neither actor nor World.
	body.role_cleanup_requested.connect(_on_cleanup.bind(weakref(body), weakref(world)))
	body.role_presence_requested.connect(_on_presence.bind(weakref(body), weakref(world)))
	body.brain_recipe_requested.connect(_on_brain_recipe.bind(weakref(body), weakref(world)))


static func _on_cleanup(request: NpcRoleCleanupRequest, actor_reference: WeakRef, world_reference: WeakRef) -> void:
	var body: E_DistrictNpc = actor_reference.get_ref() as E_DistrictNpc
	var world: World = world_reference.get_ref() as World
	# Dormant actors remain registered. Passive restore intentionally suspends Observer dispatch.
	if body == null or world == null or ECS.world != world or not world.entity_to_archetype.has(body):
		return

	match request.kind:
		NpcRoleCleanupRequest.Kind.RESET_PREPARE:
			CustomerInspectionService.end(body)
			HomeMeetingBindings.release_meeting(body)
		NpcRoleCleanupRequest.Kind.RESET_RELEASE:
			var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
			if agent != null:
				NpcServiceRole.release(body, agent.visit_id)
		NpcRoleCleanupRequest.Kind.SUSPEND:
			CustomerRoleInterruptionService.suspend(body)
			CustomerInspectionService.end(body)
			HomeMeetingBindings.release_meeting(body)
		NpcRoleCleanupRequest.Kind.DEATH:
			var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
			var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
			assert(person != null)
			NpcServiceRole.mark_dead(person, body, request.day_index)
#endregion

#region Native role presence subscription
static func _on_presence(request: NpcRolePresenceRequest, actor_reference: WeakRef, world_reference: WeakRef) -> void:
	var body: E_DistrictNpc = actor_reference.get_ref() as E_DistrictNpc
	var world: World = world_reference.get_ref() as World
	if body == null or world == null or ECS.world != world or not world.entity_to_archetype.has(body):
		return
	request.active = body.has_component(C_CustomerAgent)
#endregion

#region Higher-owned authored tree composition
static func _on_brain_recipe(request: NpcBrainRecipeRequest, actor_reference: WeakRef, world_reference: WeakRef) -> void:
	var body: E_DistrictNpc = actor_reference.get_ref() as E_DistrictNpc
	var world: World = world_reference.get_ref() as World
	if body == null or world == null or ECS.world != world or not world.entity_to_archetype.has(body):
		return
	request.tree = load(TREE_PATH) as BehaviorTree
#endregion
