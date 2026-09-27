@tool
extends Entity
## Physical wreck produced by Package destruction; exposes source metadata through C_PackageDebris.
class_name E_PackageDebris

## Runtime staging values set before World registration.
var source_package_id: String = ""
var source_definition: DEF_Package = null

func define_components() -> Array:
	var metadata: C_PackageDebris = C_PackageDebris.new()
	metadata.package_id = source_package_id
	metadata.definition = source_definition
	return [metadata]
