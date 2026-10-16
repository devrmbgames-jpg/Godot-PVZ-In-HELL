extends RefCounted
## Owns release of rear-service bindings and their exact movement token.
class_name CustomerStalkingBindings


#region Episode release
## Releases only this role episode and its motion token; durable choice/cooldown stay committed.
## A reached contact still waits to disclose its order after a lost camera/target or interruption.
static func release(body: Entity) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	var token: int = state.service_approach_task_id
	var links: Array[Relationship] = []
	for link: Relationship in body.relationships:
		if link.relation is R_CustomerStalkingTarget:
			links.append(link)
	agent.stalking_sequence = 0
	agent.stalking_deadline_tick = 0
	agent.stalking_extra_ticks = 0
	agent.stalking_destination = Vector3.INF
	var world: World = ECS.world
	NpcStalkingService.release_service_motion(body, token)
	if (
		not is_instance_valid(body) or not is_instance_valid(world)
		or ECS.world != world or not world.entity_to_archetype.has(body)
	):
		return
	for link: Relationship in links:
		if body.relationships.has(link):
			body.remove_relationship(link)
		if (
			not is_instance_valid(body) or not is_instance_valid(world)
			or ECS.world != world or not world.entity_to_archetype.has(body)
			or body.get_component(C_CustomerAgent) != agent or agent.stalking_sequence != 0
		):
			return

#endregion
