@tool
extends E_GrabbableBody
## Физический placeholder содержимого; общие impact/hazard владельцы обрабатывают эффекты.
class_name E_PackageContent

## Профиль общего расчёта удара для физического содержимого.
@export var impact_profile: DEF_ImpactProfile = preload("res://content/definitions/gameplay/def_impact_default.tres")
## Необязательная сцена самостоятельной опасности содержимого.
@export var hazard_scene: PackedScene = null


## Создаёт получатель ударов и необязательный эмиттер опасности из авторских параметров.
func define_components() -> Array:
	var receiver: C_ImpactReceiver = C_ImpactReceiver.new()
	receiver.profile = impact_profile
	var components: Array[Component] = [receiver]
	if hazard_scene != null:
		var emitter: C_HazardEmitter = C_HazardEmitter.new()
		emitter.hazard_scene = hazard_scene
		components.append(emitter)
	return components
