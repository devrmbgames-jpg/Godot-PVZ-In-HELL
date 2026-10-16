extends RefCounted
## Pure liquid capability defaults from actual selected cargo, or explicit authored legacy contents.
class_name PackageLiquidRules


#region Material phase and recipe
## A selected solid payload cannot inherit liquid state from the shell's former contents.
static func is_liquid(definition: DEF_Package, selected_item: DEF_InventoryItem) -> bool:
	if selected_item != null:
		return (
			selected_item.cargo_profile != null
			and selected_item.cargo_profile.phase == DEF_ItemCargo.Phase.LIQUID
		)
	return definition != null and bool(definition.tags & DEF_Package.Tag.LIQUID)


## Returns a detached data recipe; only the compiler or explicit restore boundary installs it.
static func recipe_for(definition: DEF_Package, selected_item: DEF_InventoryItem) -> C_LiquidTilt:
	if not is_liquid(definition, selected_item):
		return null
	var tilt: C_LiquidTilt = C_LiquidTilt.new()
	if selected_item != null:
		var cargo: DEF_ItemCargo = selected_item.cargo_profile
		tilt.maximum_angle_degrees = cargo.liquid_maximum_angle_degrees
		tilt.duration_seconds = cargo.liquid_tilt_seconds
		tilt.damage_amount = cargo.liquid_tilt_damage
	else:
		tilt.maximum_angle_degrees = definition.liquid_maximum_angle_degrees
		tilt.duration_seconds = definition.liquid_tilt_seconds
		tilt.damage_amount = definition.liquid_tilt_damage
	return tilt
#endregion
