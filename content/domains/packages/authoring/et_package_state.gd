@tool
extends EntityTrait
## Compiles package condition/content/liquid capability defaults from the scene's package Profile.
class_name ET_PackageState


#region Immutable capability contract
func _init() -> void:
	trait_id = &"package_state"
	required_root_class = &"RigidBody3D"
	required_components = [C_Package, C_Health, C_ImpactReceiver, C_Grabbable]
	initial_field_names[C_Package as Script] = PackedStringArray(["delivery_day", "supply_key"])


## Validates the existing scene export as the single immutable package tuning owner.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	if not context.actor is E_Package:
		return PackedStringArray(["Package state requires an E_Package scene instance"])
	if _definition(context) == null:
		return PackedStringArray(["Package state requires package_definition"])
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
	if definition.tags & DEF_Package.Tag.LIQUID:
		var tilt: C_LiquidTilt = C_LiquidTilt.new()
		tilt.maximum_angle_degrees = definition.liquid_maximum_angle_degrees
		tilt.duration_seconds = definition.liquid_tilt_seconds
		tilt.damage_amount = definition.liquid_tilt_damage
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
#endregion
