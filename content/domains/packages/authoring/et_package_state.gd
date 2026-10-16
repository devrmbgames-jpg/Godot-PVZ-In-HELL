@tool
extends EntityTrait
## Compiles shell defaults and liquid capability from the actual selected cargo before publication.
class_name ET_PackageState


#region Immutable capability contract
func _init() -> void:
	trait_id = &"package_state"
	required_root_class = &"RigidBody3D"
	required_components = [C_Package, C_Health, C_ImpactReceiver, C_Grabbable]
	initial_field_names[C_Package as Script] = PackedStringArray(["delivery_day", "supply_key"])
	initial_field_names[C_PackageContents as Script] = PackedStringArray(
		["selected_item", "quantity", "packing_profile"]
	)


## Validates the shell Profile and optional selected physical cargo before producing recipes.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	if not context.actor is E_Package:
		return PackedStringArray(["Package state requires an E_Package scene instance"])
	if _definition(context) == null:
		return PackedStringArray(["Package state requires package_definition"])
	var selected_item: DEF_InventoryItem = _selected_item(context)
	if selected_item != null:
		if _definition(context).unpack_scene == null:
			return PackedStringArray(["Catalog cargo requires an unpack-capable package"])
		if not PackagePackingRules.valid_cargo(selected_item.cargo_profile):
			return PackedStringArray(["Catalog cargo requires a valid physical profile"])
	var fields: Dictionary = context.initial_fields.get(C_PackageContents as Script, { })
	var quantity: int = int(fields.get(&"quantity", 0))
	var packing: DEF_PackagePacking = fields.get(&"packing_profile") as DEF_PackagePacking
	if not PackageShipmentRules.valid(
		selected_item, quantity, packing, context.actor.scene_file_path,
	):
		return PackedStringArray(["Catalog cargo requires compatible quantity and packing"])
	return PackedStringArray()
#endregion


#region Pure capability recipes
## Supplies optional contents and liquid state before registration and consumer reactions.
func recipes_for(context: EntitySpawnContext) -> Array[Component]:
	var definition: DEF_Package = _definition(context)
	if definition == null:
		return []
	var recipes: Array[Component] = []
	if definition.unpack_scene != null:
		recipes.append(C_PackageContents.new())
	var tilt: C_LiquidTilt = PackageLiquidRules.recipe_for(definition, _selected_item(context))
	if tilt != null:
		recipes.append(tilt)
	return recipes


## Configures exact scene-owned data fields; saved overlays apply later without repeating defaults.
func configuration_for(context: EntitySpawnContext) -> Dictionary[Script, Dictionary]:
	var definition: DEF_Package = _definition(context)
	var fields: Dictionary[Script, Dictionary] = { }
	if definition == null:
		return fields
	fields[C_Package as Script] = { &"condition_initialized": true }
	fields[C_Health as Script] = {
		&"base": definition.maximum_health,
		&"value": definition.maximum_health,
		&"current": definition.maximum_health,
	}
	fields[C_ImpactReceiver as Script] = { &"profile": definition.impact_profile }
	fields[C_Grabbable as Script] = { &"throw_velocity": definition.throw_velocity }
	return fields


func _definition(context: EntitySpawnContext) -> DEF_Package:
	var parcel: E_Package = context.actor as E_Package
	return parcel.package_definition if parcel != null else null


func _selected_item(context: EntitySpawnContext) -> DEF_InventoryItem:
	var fields: Dictionary = context.initial_fields.get(C_PackageContents as Script, { })
	return fields.get(&"selected_item") as DEF_InventoryItem
#endregion
