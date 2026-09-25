extends System
## Owns authoritative crouch state and collision-shape transitions.
class_name S_Crouch


func query() -> QueryBuilder:
	return q.with_all(
		[C_Controller, C_Crouch, C_RigidBody]
	).iterate(
		[C_Controller, C_Crouch]
	)


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var controllers: Array = components[0]
	var crouches: Array = components[1]

	for index: int in entities.size():
		var entity: E_RigidBodyCharacter = entities[index] as E_RigidBodyCharacter
		assert(entity != null)
		if entity == null:
			continue

		var controller: C_Controller = controllers[index]
		var crouch: C_Crouch = crouches[index]
		var wants_crouch: bool = controller.action_crouch

		if wants_crouch and not crouch.active:
			_enter_crouch(entity, crouch)
		elif not wants_crouch and crouch.active:
			var can_stand: bool = (
				entity.ray_standing == null or not entity.ray_standing.is_colliding()
			)
			if can_stand:
				_exit_crouch(entity, crouch)


func _enter_crouch(entity: E_RigidBodyCharacter, crouch: C_Crouch) -> void:
	crouch.active = true
	if entity.shape_standing != null:
		entity.shape_standing.disabled = true
	if entity.shape_crouching != null:
		entity.shape_crouching.disabled = false


func _exit_crouch(entity: E_RigidBodyCharacter, crouch: C_Crouch) -> void:
	crouch.active = false
	if entity.shape_crouching != null:
		entity.shape_crouching.disabled = true
	if entity.shape_standing != null:
		entity.shape_standing.disabled = false
