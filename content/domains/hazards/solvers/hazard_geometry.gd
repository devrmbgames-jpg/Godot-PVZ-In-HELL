extends RefCounted
## Materializes hazard collision/visual geometry without damage, clocks or spawn reactions.
class_name HazardGeometry


#region Authored geometry materialization
## Requires the prevalidated toxic prefab/profile contract.
static func configure_toxic(effect: E_ToxicArea, profile: DEF_ToxicArea) -> void:
	effect.get_area().collision_mask = profile.collision_mask
	if profile.floor_height > 0.0:
		var cylinder: CylinderShape3D = CylinderShape3D.new()
		cylinder.radius = profile.radius
		cylinder.height = profile.floor_height
		effect.get_shape().shape = cylinder
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = profile.radius
		disc.bottom_radius = profile.radius
		disc.height = profile.floor_height
		effect.get_visual().mesh = disc
		return

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = profile.radius
	effect.get_shape().shape = sphere
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.get_visual().mesh = mesh


## Configures a physical stimulus sphere and a visible flat spill without any health operation.
static func configure_blood(effect: E_BloodArea, profile: DEF_BloodArea) -> void:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = profile.radius
	effect.get_shape().shape = sphere
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = profile.radius
	mesh.bottom_radius = profile.radius
	mesh.height = 0.02
	effect.get_visual().mesh = mesh


## Requires the prevalidated explosion prefab/profile contract; never arms resolution.
static func configure_explosion(effect: E_Explosion, profile: DEF_Explosion) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = profile.radius
	mesh.height = profile.radius * 2.0
	effect.get_visual().mesh = mesh
#endregion
