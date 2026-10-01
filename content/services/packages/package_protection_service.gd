extends RefCounted
## R08 protection application boundary; impact calculation still owns severity suppression.
class_name PackageProtectionService


static func can_apply(target: Entity, tier: ImpactResult.Severity) -> bool:
	if not EntityAvailability.contains(target, ECS.world) or not target.has_component(C_Package) or tier <= ImpactResult.Severity.None or tier > ImpactResult.Severity.Strong:
		return false
	var health: C_Health = target.get_component(C_Health) as C_Health
	if health == null or health.depleted or health.current <= 0.0:
		return false
	var protection: C_ImpactProtection = target.get_component(C_ImpactProtection) as C_ImpactProtection
	return protection == null or protection.tier < tier


static func apply(target: Entity, tier: ImpactResult.Severity) -> bool:
	if not can_apply(target, tier):
		return false
	var protection: C_ImpactProtection = target.get_component(C_ImpactProtection) as C_ImpactProtection
	if protection == null:
		protection = C_ImpactProtection.new()
		protection.tier = tier
		target.add_component(protection)
	else:
		protection.tier = tier
	return true
