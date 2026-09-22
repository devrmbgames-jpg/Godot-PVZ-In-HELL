@tool
extends E_GrabbableBody
## Physical package identity and references to its own authored presentation.
class_name E_Package

## Authored IDs are stable across scene loads. Spawners/save loaders may supply an ID.
@export var package_id: String = ""
## Immutable shipment definition used when the runtime identity is initialized.
@export var package_definition: DEF_Package = null

## Box-shaped visual surface used to place ink outside collider/model tolerances.
@onready var marking_surface: MeshInstance3D = $Box_C


func define_components() -> Array:
	# This identity combines scene initialization with the spawned instance's stable ID.
	if package_id.is_empty():
		package_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var identity: C_Package = C_Package.new()
	identity.package_id = package_id
	identity.definition = package_definition
	return [identity]
