extends NpcDialogueContext
## Adapts the actual stolen-parcel incident to dialogue without resetting the service phase clock.
class_name CustomerParcelDialogueContext

var _actor_reference: WeakRef
var _customer_reference: WeakRef
var _agent: C_CustomerAgent


#region Conversation lifetime
func _init(actor: Entity, customer: E_DistrictNpc, agent: C_CustomerAgent) -> void:
	super(actor, customer)
	_actor_reference = weakref(actor)
	_customer_reference = weakref(customer)
	_agent = agent


func begin() -> bool:
	var actor: Entity = _actor_reference.get_ref() as Entity
	var customer: E_DistrictNpc = _customer_reference.get_ref() as E_DistrictNpc
	if (
		_closed or not EntityAvailability.contains(actor, ECS.world)
		or not EntityAvailability.contains(customer, ECS.world)
		or customer.get_component(C_CustomerAgent) != _agent
		or CustomerParcelDemandQueries.available(actor, customer) == null
	):
		return false
	return NpcDialogueService.begin(actor, customer)


## Releases only this conversation; preserves the original service phase and elapsed time.
func end() -> void:
	if _closed:
		return
	_closed = true
	var actor: Entity = _actor_reference.get_ref() as Entity
	var customer: E_DistrictNpc = _customer_reference.get_ref() as E_DistrictNpc
	if customer != null and NpcDialogueService.participant(customer) == actor:
		NpcDialogueService.end(customer)


func is_valid() -> bool:
	var actor: Entity = _actor_reference.get_ref() as Entity
	var customer: E_DistrictNpc = _customer_reference.get_ref() as E_DistrictNpc
	return (
		not _closed and EntityAvailability.contains(actor, ECS.world)
		and EntityAvailability.contains(customer, ECS.world)
		and customer.get_component(C_CustomerAgent) == _agent
		and CustomerParcelDemandQueries.available_in_dialogue(actor, customer) != null
	)


## Разрешает текущего физического собеседника для общего read-only имени личности.
func _delivery_npc() -> E_DistrictNpc:
	return _customer_reference.get_ref() as E_DistrictNpc


func can_continue() -> bool:
	return is_valid()


func speaks_with(npc: Entity) -> bool:
	return not _closed and _customer_reference.get_ref() == npc


func apply_response_tags(tags: PackedStringArray) -> bool:
	return tags.is_empty() and can_continue()
#endregion


#region Authored demand branch
## Reads the saved outcome; a pending physical claim never draws another intimidation result.
func parcel_return_pending() -> bool:
	if not is_valid():
		return false
	var incident: CustomerParcelIncident = CustomerParcelDemandQueries.available_in_dialogue(
		_actor_reference.get_ref() as Entity,
		_customer_reference.get_ref() as E_DistrictNpc,
	)
	return incident.demand_outcome == CustomerParcelReactionRules.DemandOutcome.RETURN


## Closes native modal UI before submitting the same incident to its existing transaction owner.
func request_parcel_return() -> bool:
	if not is_valid():
		return false
	var actor: Entity = _actor_reference.get_ref() as Entity
	var customer: E_DistrictNpc = _customer_reference.get_ref() as E_DistrictNpc
	var incident: CustomerParcelIncident = CustomerParcelDemandQueries.available_in_dialogue(
		actor,
		customer,
	)
	NpcDialogueService.close_for(customer)
	invalidate()
	# Closing may publish callbacks that replace the role, parcel or either participant.
	if (
		not EntityAvailability.contains(actor, ECS.world)
		or not EntityAvailability.contains(customer, ECS.world)
		or customer.get_component(C_CustomerAgent) != _agent
		or CustomerParcelDemandQueries.available(actor, customer) != incident
	):
		return false
	return CustomerParcelDemandService.demand(actor, customer)
#endregion
