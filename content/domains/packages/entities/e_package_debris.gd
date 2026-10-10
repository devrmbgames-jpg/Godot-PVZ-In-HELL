@tool
extends E_TraitedEntity
## Физические обломки коробки; исходные данные доступны через C_PackageDebris.
class_name E_PackageDebris

## Исходные данные, устанавливаемые перед регистрацией обломков в World.
var _source_package_id: String = ""
var _source_definition: DEF_Package = null

## Задаёт исходную посылку до добавления обломков в World и создания компонентов.
func configure_source(package_id: String, definition: DEF_Package) -> void:
	_source_package_id = package_id
	_source_definition = definition


## Создаёт C_PackageDebris из предварительно заданных данных источника.
func define_components() -> Array[Component]:
	if EntityCompositionService.recipes_prepared(self):
		return []
	var metadata: C_PackageDebris = C_PackageDebris.new()
	metadata.package_id = _source_package_id
	metadata.definition = _source_definition
	return [metadata]
