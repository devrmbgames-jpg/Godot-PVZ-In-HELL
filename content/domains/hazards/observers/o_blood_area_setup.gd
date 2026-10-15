extends Observer
## Discrete blood-zone setup after the existing factory publishes a committed spawn/restore.
class_name O_BloodAreaSetup


#region Committed volume setup
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_BloodArea]).on_event(HazardSpawnResult.EVENT)


## Планирует геометрию; WeakRef и identity двух Components отсекают устаревший spawn fact.
func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	var blood: C_BloodArea = entity.get_component(C_BloodArea) as C_BloodArea
	cmd.add_custom(_configure.bind(weakref(entity), hazard, blood))


func _configure(reference: WeakRef, hazard: C_Hazard, blood: C_BloodArea) -> void:
	var entity: Entity = reference.get_ref() as Entity
	if (
		not EntityAvailability.contains(entity, _world) or entity.get_component(C_Hazard) != hazard
		or entity.get_component(C_BloodArea) != blood
	):
		return
	var effect: E_BloodArea = entity as E_BloodArea
	var profile: DEF_BloodArea = hazard.definition as DEF_BloodArea
	if effect == null or not HazardProfileRules.valid(profile):
		push_error("Blood zone requires an E_BloodArea prefab and valid DEF_BloodArea")
		HazardLifecycle.retire(entity, _world)
		return
	HazardGeometry.configure_blood(effect, profile)
#endregion
