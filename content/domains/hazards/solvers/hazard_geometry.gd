extends RefCounted
## Materializes hazard collision/visual geometry without damage, clocks or spawn reactions.
class_name HazardGeometry

#region Authored geometry materialization
## Requires the prevalidated toxic prefab/profile contract.
static func configure_toxic(effect: E_ToxicArea, profile: DEF_ToxicArea) -> void:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = profile.radius
	effect.get_shape().shape = sphere
	effect.get_area().collision_mask = profile.collision_mask
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.get_visual().mesh = mesh


## Requires the prevalidated explosion prefab/profile contract; never arms resolution.
static func configure_explosion(effect: E_Explosion, profile: DEF_Explosion) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.get_visual().mesh = mesh
#endregion
