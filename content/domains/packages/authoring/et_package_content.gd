@tool
extends EntityTrait
## Compiles content impact and optional hazard data from the native scene's authored fields.
class_name ET_PackageContent


#region Pure authored content recipes
func _init() -> void:
	trait_id = &"package_content"
	required_root_class = &"RigidBody3D"


## Rejects incompatible roots and missing tuning without inspecting or mutating the live World.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	var content: E_PackageContent = context.actor as E_PackageContent
	if content == null:
		return PackedStringArray(["Package content requires an E_PackageContent root"])
	if content.impact_profile == null:
		return PackedStringArray(["Package content requires its authored impact Profile"])
	return PackedStringArray()


## Fresh Components retain the scene's single immutable Profile/Scene references.
func recipes_for(context: EntitySpawnContext) -> Array[Component]:
	var content: E_PackageContent = context.actor as E_PackageContent
	if content == null:
		return []
	var receiver: C_ImpactReceiver = C_ImpactReceiver.new()
	receiver.profile = content.impact_profile
	var recipes: Array[Component] = [receiver]

	if content.hazard_scene != null:
		var emitter: C_HazardEmitter = C_HazardEmitter.new()
		emitter.hazard_scene = content.hazard_scene
		recipes.append(emitter)
	return recipes
#endregion
