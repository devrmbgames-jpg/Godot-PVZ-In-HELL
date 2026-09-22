@tool
extends E_Grabbable
class_name E_Package

## Authored IDs are stable across scene loads. Spawners/save loaders may supply an ID.
@export var package_id: String = ""
@export var package_definition: DEF_Package = null


func define_components() -> Array:
	# This identity combines scene initialization with the spawned instance's stable ID.
	if package_id.is_empty():
		package_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var identity: C_Package = C_Package.new()
	identity.package_id = package_id
	identity.definition = package_definition
	return [identity]
