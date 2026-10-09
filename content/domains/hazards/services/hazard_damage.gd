extends RefCounted
## Передаёт воздействие опасности в общий контур урона без собственной арифметики HP.
class_name HazardDamage


## Отправляет эффект как источник; постоянная атрибуция сохраняется после удаления инициатора.
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
