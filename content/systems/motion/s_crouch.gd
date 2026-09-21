extends System
class_name S_Crouch


static func integrate_forces(
	entity: E_RigidBodyCharacter,
	state: PhysicsDirectBodyState3D
) -> void:
	
	assert(entity as Node as RigidBody3D, "is not rigid!")
	
	var controller := entity.get_component(
		C_Controller
	) as C_Controller
	
	var crouch := entity.get_component(
		C_Crouch
	) as C_Crouch
	
	if controller == null or crouch == null:
		return
	
	var wants_crouch := controller.action_crouch
	
	if wants_crouch:
		if not crouch.active:
			S_Crouch._enter_crouch(
				entity,
				crouch
			)
	else:
		if crouch.active:
			if S_Crouch._can_stand(
				entity,
				state
			):
				S_Crouch._exit_crouch(
					entity,
					crouch
				)
	
	S_Crouch._update_visuals(
		entity,
		crouch,
		state.step
	)


static func _enter_crouch(
	entity: E_RigidBodyCharacter,
	crouch: C_Crouch
) -> void:
	crouch.active = true
	
	if entity.shape_standing != null:
		entity.shape_standing.disabled = true
	
	if entity.shape_crouching != null:
		entity.shape_crouching.disabled = false


static func _exit_crouch(
	entity: E_RigidBodyCharacter,
	crouch: C_Crouch
) -> void:
	crouch.active = false
	
	if entity.shape_crouching != null:
		entity.shape_crouching.disabled = true
	
	if entity.shape_standing != null:
		entity.shape_standing.disabled = false


static func _can_stand(
	entity: E_RigidBodyCharacter,
	state: PhysicsDirectBodyState3D
) -> bool:
	if entity.shape_standing == null:
		return true
	
	var shape := entity.shape_standing.shape
	
	if shape == null:
		return true
	
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = entity.shape_standing.global_transform
	
	params.collision_mask = (
		entity.collision_mask
	)
	
	params.exclude = [
		entity.get_rid()
	]
	
	var space_state := state.get_space_state()
	
	var result := space_state.intersect_shape(
		params,
		1
	)
	
	return result.is_empty()





static func _update_visuals(
	entity: E_RigidBodyCharacter,
	crouch: C_Crouch,
	delta: float
) -> void:
	if entity.camera_root == null:
		return
	
	var target_height := (
		crouch.camera_height_crouching
		if crouch.active
		else crouch.camera_height_standing
	)
	
	var position := entity.camera_root.position
	
	position.y = move_toward(
		position.y,
		target_height,
		crouch.transition_speed * delta
	)
	
	entity.camera_root.position = position
