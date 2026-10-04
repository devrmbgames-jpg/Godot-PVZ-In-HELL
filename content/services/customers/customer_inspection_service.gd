extends RefCounted
## Bounded optional visit behavior. Relationships own booth/cargo; existing slots carry bodies.
class_name CustomerInspectionService


static func owner_for(item: Entity) -> E_Customer:
	if not EntityAvailability.contains(item, ECS.world):
		return null

	for binding: Relationship in item.relationships:
		if binding.relation is R_InspectionCargo and EntityAvailability.contains(binding.target as Entity, ECS.world):
			var customer: E_Customer = binding.target as E_Customer
			if customer != null and not customer.has_component(C_Death):
				return customer
	return null


static func cargo(customer: Entity) -> Array[Entity]:
	if not is_instance_valid(ECS.world):
		return []
	return ECS.world.query.with_relationship([Relationship.new(R_InspectionCargo.new(), customer)]).execute().duplicate()


static func parcel_for(customer: Entity) -> Entity:
	for item: Entity in cargo(customer):
		for binding: Relationship in item.relationships:
			if binding.relation is R_InspectionCargo and binding.target == customer and (binding.relation as R_InspectionCargo).original_parcel:
				return item
	return null


static func begin(customer: E_Customer, visit: CustomerVisit, parcel: Entity) -> bool:
	if visit == null or visit.definition == null or visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED or not visit.definition.private_inspection or not EntityAvailability.contains(customer, ECS.world) or customer.has_component(C_Death) or not EntityAvailability.contains(parcel, ECS.world):
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return false

	var slot: E_PhysicalSlot = customer.get_node_or_null("InspectionParcelSlot") as E_PhysicalSlot
	if slot == null or owner_for(parcel) != null or PhysicalSlotService.relationship(parcel) != null:
		return false

	var booth: Entity = null
	for candidate: Entity in ECS.world.query.with_all([C_InspectionBooth]).execute():
		var config: C_InspectionBooth = candidate.get_component(C_InspectionBooth) as C_InspectionBooth
		if config.enabled and (candidate as Node) is Node3D and ECS.world.query.with_relationship([Relationship.new(R_InspectingAt.new(), candidate)]).execute().is_empty():
			booth = candidate
			break

	var home_door: Entity = NpcHomeDeliveryService.door_for(customer)
	if home_door != null:
		booth = home_door
	if booth == null:
		return false
	if not EntityAvailability.contains(slot, ECS.world):
		ECS.world.add_entity(slot, null, false)
	var stored: Relationship = Relationship.new(R_StoredIn.new(), slot)
	parcel.add_relationship(stored)
	if not PhysicalSlotService.attach(parcel, stored):
		if stored in parcel.relationships:
			parcel.remove_relationship(stored)
		return false

	var reservation: R_InspectionCargo = R_InspectionCargo.new()
	reservation.original_parcel = true
	parcel.add_relationship(Relationship.new(reservation, customer))
	customer.add_relationship(Relationship.new(R_InspectingAt.new(), booth))
	agent.inspection_open_attempted = false
	agent.inspection_force_refusal = false
	if home_door != null:
		_transition(agent, C_CustomerAgent.Phase.INSPECTING)
		NpcIntentService.stop(customer)
		customer.show_message("Осмотрю заказ здесь, у двери.")
		return true

	_transition(agent, C_CustomerAgent.Phase.GOING_TO_BOOTH)
	NpcIntentService.move_to(customer, (booth as Node as Node3D).global_position, visit.definition.arrival_distance)
	NpcIntentService.look_along_movement(customer)
	customer.show_message("Я осмотрю заказ в кабинке и вернусь.")
	return true


## Called by the existing contents observer after real physical extraction.
static func bind_contents(package: Entity, contents: Array[Entity]) -> void:
	var customer: E_Customer = owner_for(package)
	if customer == null:
		return

	for item: Entity in contents:
		if EntityAvailability.contains(item, ECS.world):
			item.add_relationship(Relationship.new(R_InspectionCargo.new(), customer))


## True means the customer is back (or the return timed out) and can decide once.
static func tick(customer: E_Customer, visit: CustomerVisit) -> bool:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent
	if parcel_for(customer) == null:
		agent.inspection_force_refusal = true
		return true

	match agent.phase:
		C_CustomerAgent.Phase.GOING_TO_BOOTH:
			if intent != null and intent.arrived:
				_transition(agent, C_CustomerAgent.Phase.INSPECTING)
				NpcIntentService.stop(customer)
				customer.show_message("Осматриваю заказ…")
			elif agent.elapsed >= visit.definition.approach_timeout:
				agent.inspection_force_refusal = true
				_return(customer, agent, visit)
		C_CustomerAgent.Phase.INSPECTING:
			if not agent.inspection_open_attempted:
				agent.inspection_open_attempted = true
				if roll(visit, "unpack") < visit.definition.inspection_unpack_probability:
					PackageOpening.request_open(customer, parcel_for(customer))
			if agent.elapsed >= visit.definition.inspection_seconds:
				_return(customer, agent, visit)
		C_CustomerAgent.Phase.RETURNING_FROM_BOOTH:
			if intent != null and intent.arrived:
				return true
			if agent.elapsed >= visit.definition.approach_timeout:
				agent.inspection_force_refusal = true
				return true
	return false


static func roll(visit: CustomerVisit, choice: String) -> float:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = String("%s/inspection/%d/%s" % [visit.visit_id, visit.visit_count, choice]).hash()
	return random.randf()


## Releases native mounts and all temporary ownership; only accepted contents leave the world.
static func end(customer: Entity, keep_contents: bool = false) -> void:
	for item: Entity in cargo(customer):
		var original: bool = item == parcel_for(customer)
		if original:
			PhysicalSlotService.release(item)
		for binding: Relationship in item.relationships.duplicate():
			if binding.relation is R_InspectionCargo and binding.target == customer:
				item.remove_relationship(binding)
		if keep_contents and not original:
			ECS.world.remove_entity(item)
	for binding: Relationship in customer.relationships.duplicate():
		if binding.relation is R_InspectingAt:
			customer.remove_relationship(binding)


static func _return(customer: E_Customer, agent: C_CustomerAgent, visit: CustomerVisit) -> void:
	_transition(agent, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH)
	var home_door: Entity = NpcHomeDeliveryService.door_for(customer)
	if home_door != null:
		NpcIntentService.move_to(customer, (home_door as Node as Node3D).global_position, visit.definition.arrival_distance)
		return

	var counter: E_DeliveryCounter = CustomerFlowService.counter()
	if counter != null:
		NpcIntentService.move_to(customer, counter.waiting_position(), visit.definition.arrival_distance)
		NpcIntentService.look_along_movement(customer)
	else:
		agent.inspection_force_refusal = true
	customer.show_message("Возвращаюсь после осмотра.")


static func _transition(agent: C_CustomerAgent, phase: C_CustomerAgent.Phase) -> void:
	agent.phase = phase
	agent.elapsed = 0.0
