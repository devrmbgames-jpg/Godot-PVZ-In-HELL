@tool
extends Entity
## Physical wreck produced by Package destruction; exposes source metadata through C_PackageDebris.
class_name E_PackageDebris

## Runtime staging values set before World registration.
var _source_package_id: String = ""
var _source_definition: DEF_Package = null

func configure_source(package_id: String, definition: DEF_Package) -> void:
	_source_package_id = package_id
	_source_definition = definition


func define_components() -> Array:
	var metadata: C_PackageDebris = C_PackageDebris.new()
	metadata.package_id = _source_package_id
	metadata.definition = _source_definition
	return [metadata]
