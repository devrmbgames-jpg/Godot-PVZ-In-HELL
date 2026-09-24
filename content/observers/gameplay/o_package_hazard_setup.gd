extends Observer
## Package-only data adapter; the generic hazard processors never inspect package tags/classes.
class_name O_PackageHazardSetup

const TOXIC: DEF_Hazard = preload("res://content/definitions/gameplay/hazards/toxic_spill.tres")
const EXPLOSIVE: DEF_Hazard = preload(
	"res://content/definitions/gameplay/hazards/parcel_blast.tres"
)


func query() -> QueryBuilder:
	return q.with_all([C_Package]).on_match()


func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
	if entity.has_component(C_HazardEmitter):
		return

	var identity: C_Package = entity.get_component(C_Package) as C_Package
	var definition: DEF_Package = identity.definition
	if definition == null:
		return

	var effect: DEF_Hazard = definition.hazard_effect
	if effect == null:
		match definition.hazard:
			DEF_Package.Hazard.TOXIC:
				effect = TOXIC
			DEF_Package.Hazard.EXPLOSIVE:
				effect = EXPLOSIVE

	if effect == null:
		return

	var emitter: C_HazardEmitter = C_HazardEmitter.new()
	emitter.definition = effect
	emitter.triggers = definition.hazard_triggers
	if emitter.triggers == 0:
		emitter.triggers = C_HazardEmitter.Trigger.PackageDestroyed
		if definition.hazard == DEF_Package.Hazard.TOXIC:
			emitter.triggers |= C_HazardEmitter.Trigger.PackageLeaking

	cmd.add_component(entity, emitter)
