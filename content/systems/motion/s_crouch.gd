extends System
class_name S_Crouch


func query() -> QueryBuilder:
	return q.with_all(
		[C_Controller, C_Crouch, C_RigidBody]
	).iterate(
		[C_Controller, C_Crouch]
	)


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var c_controller_list: Array = components[0]
	var c_crouch_list: Array = components[1]
	
	for idx in entities.size() :
		var entity: E_RigidBodyCharacter = entities[idx] as E_RigidBodyCharacter
		assert(entity)
		var entity_rigid: RigidBody3D = entity as Node as RigidBody3D
		assert(entity_rigid)
		
		var c_controller: C_Controller = c_controller_list[idx]
		var c_crouch: C_Crouch = c_crouch_list[idx]
		
		var wants_crouch := c_controller.action_crouch
		var has_crouch := c_crouch.active
		
		if wants_crouch and not has_crouch :
			_enter_crouch(
				entity,
				c_crouch
			)
		elif not wants_crouch and has_crouch :
			var can_stand: bool = entity.ray_standing.is_colliding() == false
			if can_stand :
				_exit_crouch(
					entity,
					c_crouch
				)
		
		_update_visuals(
			entity,
			c_crouch,
			delta
		)


	


func _enter_crouch(
	entity: E_RigidBodyCharacter,
	crouch: C_Crouch
) -> void:
	crouch.active = true
	
	if entity.shape_standing != null:
		entity.shape_standing.disabled = true
	
	if entity.shape_crouching != null:
		entity.shape_crouching.disabled = false


func _exit_crouch(
	entity: E_RigidBodyCharacter,
	crouch: C_Crouch
) -> void:
	crouch.active = false
	
	if entity.shape_crouching != null:
		entity.shape_crouching.disabled = true
	
	if entity.shape_standing != null:
		entity.shape_standing.disabled = false




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
