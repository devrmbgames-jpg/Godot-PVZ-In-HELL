@tool
extends E_GrabbableBody
## Физический placeholder содержимого; общие impact/hazard владельцы обрабатывают эффекты.
class_name E_PackageContent

@export var impact_profile: DEF_ImpactProfile = preload("res://content/definitions/gameplay/def_impact_default.tres")
@export var hazard_scene: PackedScene = null


func define_components() -> Array:
	var receiver: C_ImpactReceiver = C_ImpactReceiver.new()
	receiver.profile = impact_profile
	var components: Array[Component] = [receiver]
	if hazard_scene != null:
		var emitter: C_HazardEmitter = C_HazardEmitter.new()
		emitter.hazard_scene = hazard_scene
		components.append(emitter)
	return components
