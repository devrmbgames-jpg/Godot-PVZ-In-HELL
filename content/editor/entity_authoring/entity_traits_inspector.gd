@tool
extends EditorInspectorPlugin
## Replaces only the direct traits property, preserving the standard Entity Inspector.

const _TRAITS_PROPERTY: GDScript = preload(
	"res://content/editor/entity_authoring/entity_traits_property.gd"
)


func _can_handle(object: Object) -> bool:
	return object is E_TraitedEntity


func _parse_property(
	_object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool,
) -> bool:
	if name != "traits":
		return false
	var property: EditorProperty = _TRAITS_PROPERTY.new() as EditorProperty
	add_property_editor(name, property)
	return true
