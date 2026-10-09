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


## Создаёт постоянную запись посылки; при отсутствии авторского ID генерирует его для этого экземпляра.
func define_components() -> Array:
	# Инициализация сцены сохраняет постоянный ID, заранее переданный созданному экземпляру.
	if package_id.is_empty():
		package_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var identity: C_Package = C_Package.new()
	identity.package_id = package_id
	identity.definition = package_definition
	
	var components: Array[Component] = [identity]
	if package_definition != null and package_definition.unpack_scene != null:
		components.append(C_PackageContents.new())
	return components
