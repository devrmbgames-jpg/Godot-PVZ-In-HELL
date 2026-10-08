extends RefCounted
## Управляет осмотром: Relationships резервируют место и груз, PhysicalSlotService крепит тела.
class_name CustomerInspectionService


#region Резервы осмотра
## Крепит коробку к слоту клиента и резервирует кабинку либо дверь домашней встречи.
static func begin(customer: E_NpcCharacter, visit: CustomerVisit, parcel: Entity) -> bool:
	if visit == null or visit.definition == null or visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED or not visit.definition.private_inspection or not EntityAvailability.contains(customer, ECS.world) or customer.has_component(C_Death) or not EntityAvailability.contains(parcel, ECS.world):
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return false

	var slot: E_PhysicalSlot = customer.get_node_or_null("InspectionParcelSlot") as E_PhysicalSlot
	if slot == null or CustomerInspectionQueries.owner_for(parcel) != null or PhysicalSlotService.relationship(parcel) != null:
		return false

	var booth: Entity = null
	for candidate: Entity in ECS.world.query.with_all([C_InspectionBooth]).execute():
		var config: C_InspectionBooth = candidate.get_component(C_InspectionBooth) as C_InspectionBooth
		if config.enabled and (candidate as Node) is Node3D and ECS.world.query.with_relationship([Relationship.new(R_InspectingAt.new(), candidate)]).execute().is_empty():
			booth = candidate
			break

	var home_door: Entity = HomeMeetingQueries.door_for(customer)
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


## Резервирует содержимое по уведомлению наблюдателя после реального извлечения из коробки.
static func bind_contents(package: Entity, contents: Array[Entity]) -> void:
	var customer: E_NpcCharacter = CustomerInspectionQueries.owner_for(package)
	if customer == null:
		return

	for item: Entity in contents:
		if EntityAvailability.contains(item, ECS.world):
			item.add_relationship(Relationship.new(R_InspectionCargo.new(), customer))


#endregion

#region Исполнение и завершение осмотра
## Возвращает стабильный бросок 0–1 для выбора и номера прихода; повтор не меняет исход.
static func roll(visit: CustomerVisit, choice: String) -> float:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = String("%s/inspection/%d/%s" % [visit.visit_id, visit.visit_count, choice]).hash()
	return random.randf()


## Освобождает крепления и временные связи; принятое содержимое удаляется из мира.
static func end(customer: Entity, keep_contents: bool = false) -> void:
	var parcel: Entity = CustomerInspectionQueries.parcel_for(customer)
	if keep_contents and parcel != null:
		LootDropService.accept_contents(parcel)

	for item: Entity in CustomerInspectionQueries.cargo(customer):
		var original: bool = item == CustomerInspectionQueries.parcel_for(customer)
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


## Фиксирует прибытие в кабинку, не выбирая следующее действие.
static func arrive(customer: E_NpcCharacter) -> void:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	_transition(agent, C_CustomerAgent.Phase.INSPECTING)
	NpcIntentService.stop(customer)
	customer.show_message("Осматриваю заказ…")

## Один раз запрашивает вскрытие; состав предметов по-прежнему создаёт PackageOpening.
static func inspect_contents(customer: E_NpcCharacter, visit: CustomerVisit) -> void:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent.inspection_open_attempted:
		return
	agent.inspection_open_attempted = true
	if roll(visit, "unpack") < visit.definition.inspection_unpack_probability:
		PackageOpening.request_open(customer, CustomerInspectionQueries.parcel_for(customer))

## Запрашивает возвращение с осмотра; момент перехода определяет дерево.
static func return_to_service(customer: E_NpcCharacter, visit: CustomerVisit, force_refusal: bool = false) -> void:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.inspection_force_refusal = agent.inspection_force_refusal or force_refusal
	_return(customer, agent, visit)

## Возвращает положение текущего резерва осмотра либо точки обслуживания.
static func destination(customer: E_NpcCharacter) -> Vector3:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent.phase == C_CustomerAgent.Phase.GOING_TO_BOOTH:
		for link: Relationship in customer.relationships:
			if link.relation is R_InspectingAt:
				return (link.target as Node3D).global_position
	var door: Entity = HomeMeetingQueries.door_for(customer)
	return (door as Node as Node3D).global_position if door != null else CustomerFlowQueries.counter().waiting_position()

static func _return(customer: E_NpcCharacter, agent: C_CustomerAgent, visit: CustomerVisit) -> void:
	_transition(agent, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH)
	var home_door: Entity = HomeMeetingQueries.door_for(customer)
	if home_door != null:
		NpcIntentService.move_to(customer, (home_door as Node as Node3D).global_position, visit.definition.arrival_distance)
		return

	var counter: E_DeliveryCounter = CustomerFlowQueries.counter()
	if counter != null:
		NpcIntentService.move_to(customer, counter.waiting_position(), visit.definition.arrival_distance)
		NpcIntentService.look_along_movement(customer)
	else:
		agent.inspection_force_refusal = true
	customer.show_message("Возвращаюсь после осмотра.")


static func _transition(agent: C_CustomerAgent, phase: C_CustomerAgent.Phase) -> void:
	agent.phase = phase
	agent.elapsed = 0.0

#endregion
