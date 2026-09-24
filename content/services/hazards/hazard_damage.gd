extends RefCounted
## Translates an effect hit into the shared damage channel without owning HP arithmetic.
class_name HazardDamage


## Effect is always the damaging source; stable attribution survives removal of the initiator.
static func submit(
	effect: Entity,
	hazard: C_Hazard,
	target: Entity,
	amount: float,
	damage_type: DamageRequest.Type,
) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.source = effect
	request.target = target
	request.instigator = hazard.instigator if is_instance_valid(hazard.instigator) else null
	request.origin_id = hazard.origin_id
	request.instigator_id = hazard.instigator_id
	request.amount = amount
	request.damage_type = damage_type
	DamageRequestService.submit(request)
