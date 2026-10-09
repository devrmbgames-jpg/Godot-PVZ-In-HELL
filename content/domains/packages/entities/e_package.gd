@tool
extends E_GrabbableBody
## Физическая коробка с постоянным ID и ссылкой на собственную поверхность для чернил.
class_name E_Package

## Авторский постоянный ID; поставка и загрузка могут задать его до регистрации сущности в World.
@export var package_id: String = ""
## Авторское определение, из которого инициализируется постоянная запись посылки.
@export var package_definition: DEF_Package = null

## Прямоугольная поверхность коробки для размещения чернил с отступом от модели и коллайдера.
@onready var _marking_surface: MeshInstance3D = $Box_C


## Возвращает собственную поверхность Box_C для локальных штрихов.
func get_marking_surface() -> MeshInstance3D:
	return _marking_surface


#region Runtime instance identity
func _enter_tree() -> void:
	# Identity allocation belongs to the runtime instance boundary, never recipe preview.
	if not Engine.is_editor_hint() and package_id.is_empty():
		package_id = Crypto.new().generate_random_bytes(16).hex_encode()
#endregion

#region Intrinsic package metadata
## Returns fresh identity/configuration data without assigning identity or mutating authoring inputs.
func define_components() -> Array[Component]:
	if EntityCompositionService.recipes_prepared(self):
		return []
	var identity: C_Package = C_Package.new()
	identity.package_id = package_id
	identity.definition = package_definition
	
	return [identity]
#endregion
