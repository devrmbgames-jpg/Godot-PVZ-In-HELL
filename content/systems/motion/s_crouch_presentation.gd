extends System
## Shared head-root geometry driven by C_Crouch; legacy class/scene name is preserved.
## HeadRoot also carries the interaction ray and hold anchors, so this is gameplay glue.
class_name S_CrouchPresentation


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_Crouch] }


func query() -> QueryBuilder:
	return q.with_all([C_Crouch]).with_any([C_RigidBody, C_CharacterBody]).iterate([C_Crouch])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var crouches: Array = components[0]

	for index: int in entities.size():
		var entity: E_PhysicalCharacter = entities[index] as E_PhysicalCharacter
		if entity == null or entity.camera_root == null:
			continue
		var crouch: C_Crouch = crouches[index]
		var target_height: float = (
			crouch.camera_height_crouching
			if crouch.active
			else crouch.camera_height_standing
		)
		var position: Vector3 = entity.camera_root.position
		position.y = move_toward(
			position.y,
			target_height,
			crouch.transition_speed * delta,
		)
		entity.camera_root.position = position
