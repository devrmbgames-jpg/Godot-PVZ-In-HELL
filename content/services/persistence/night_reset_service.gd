extends RefCounted
class_name NightResetService


static func reset() -> void:
	if not is_instance_valid(ECS.world):
		return
	for node: Node in ECS.world.get_parent().find_children("*", "", true, false):
		if node is InventoryPanel:
			(node as InventoryPanel).close_inventory()
		elif node is TerminalPanel:
			(node as TerminalPanel).close_panel()
		elif node is CustomerDialoguePanel:
			(node as CustomerDialoguePanel).close_dialogue()
		elif node is CommercePanel:
			(node as CommercePanel).close_panel()
	for entity: Entity in ECS.world.entities.duplicate():
		if not is_instance_valid(entity):
			continue
		ChallengeService.cancel(entity)
		ProlongedInteractionService.cancel(entity)
		PersistentInteractionState.reset_incomplete(entity)
		OpenableService.cancel_player_request(entity)
		CombatService.end_combat(entity)
		if entity.has_component(C_CartTransport):
			CartTransportService.end(entity)
		var pushed: Entity = PushService.pushed_object(entity)
		if pushed != null:
			PushService.end(entity, pushed)
		if entity.has_component(C_Marker):
			MarkerSessionService.end(entity)
		if entity.has_component(C_GrabControl):
			for slot: int in 3:
				var item: Entity = GrabService.held_in_slot(entity, slot)
				if item != null:
					GrabService.release(entity, item, false)
			var control: C_GrabControl = entity.get_component(C_GrabControl) as C_GrabControl
			control.captures.clear()
			control.rotation_active = false
		if entity.has_component(C_CustomerAgent) and not entity.has_component(C_NpcIdentity):
			CustomerInspectionService.end(entity)
			ECS.world.remove_entity(entity)
		elif entity.has_component(C_CombatProjectile):
			ECS.world.remove_entity(entity)
		elif entity.has_component(C_HazardLifetime) and not (entity.get_component(C_HazardLifetime) as C_HazardLifetime).persistent:
			HazardLifecycle.retire(entity, ECS.world)
		var body: RigidBody3D = entity as Node as RigidBody3D if is_instance_valid(entity) else null
		if body != null:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
	PersistentHazardState.reset_missing_owners()
