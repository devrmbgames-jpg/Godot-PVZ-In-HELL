extends Observer
## World-to-native UI composition adapter; существующие панели и контексты остаются Godot objects.
class_name O_DialoguePanelRequest

#region Явные domain requests
## Доставляет только opening/closing requests native presentation owner.
func sub_observers() -> Array[Array]:
	return [
		[q.on_event(CustomerDialogueOpenRequest.EVENT), _open_customer],
		[q.on_event(NpcDialogueOpenRequest.EVENT), _open_street],
		[q.on_event(NpcDialogueCloseRequest.EVENT), _close],
	]


func _open_customer(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	var request: CustomerDialogueOpenRequest = payload as CustomerDialogueOpenRequest
	assert(request != null)
	var actor: Entity = request.actor_reference.get_ref() as Entity
	if not EntityAvailability.contains(actor, _world) or actor.id != request.actor_id or not EntityAvailability.contains(subject, _world):
		return
	if subject.get_component(C_CustomerAgent) != request.agent:
		return
	var customer: E_NpcCharacter = subject as E_NpcCharacter
	assert(customer != null)
	request.opened = DialoguePanelRouter.open_customer(actor, customer, request.agent)


func _open_street(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	var request: NpcDialogueOpenRequest = payload as NpcDialogueOpenRequest
	assert(request != null)
	var player: Entity = request.actor_reference.get_ref() as Entity
	if not EntityAvailability.contains(player, _world) or player.id != request.actor_id or not EntityAvailability.contains(subject, _world):
		return
	if subject.get_component(C_NpcIdentity) != request.identity:
		return
	var body: E_DistrictNpc = subject as E_DistrictNpc
	assert(body != null)
	request.opened = DialoguePanelRouter.open_street(player, body)


func _close(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	assert(payload is NpcDialogueCloseRequest)
	# Closing also applies to registered dormant bodies; native UI owns its panel lifetime.
	if _world.entity_to_archetype.has(subject) and (subject as Node).is_inside_tree():
		DialoguePanelRouter.close_for(subject)
#endregion
