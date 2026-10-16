@tool
extends DEF_InteractionAction
## Contextual native action for an actual appropriation; shared Definition retains no runtime state.
class_name DEF_CustomerParcelDemandAction

const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")


#region Demand interaction
func caption_for(actor: Entity, source: Entity, _target: Entity) -> String:
	var incident: CustomerParcelIncident = CustomerParcelDemandQueries.available(
		actor,
		source as E_DistrictNpc,
	)
	if incident != null and incident.demand_outcome == REACTIONS.DemandOutcome.RETURN:
		return tr("Забрать посылку")
	return caption


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CustomerParcelDemandQueries.available(actor, source as E_DistrictNpc) != null


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerParcelDemandService.demand(actor, source as E_DistrictNpc)


func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CustomerParcelDemandService.demand(actor, source as E_DistrictNpc)
#endregion
