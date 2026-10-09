extends System
## Смещает общий корень головы по C_Crouch после авторитетного переключения состояния.
## Корень содержит камеру, луч взаимодействия и крепления хвата; смещение влияет на игровой доступ.
class_name S_CrouchPresentation


## Смещает геометрию после авторитетного S_Crouch.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_Crouch] }


## Выбирает персонажей обоих физических типов с C_Crouch.
func query() -> QueryBuilder:
	return q.with_all([C_Crouch]).with_any([C_RigidBody, C_CharacterBody]).iterate([C_Crouch])


## За шаг в секундах приближает высоту головы и поясных креплений к высоте текущей позы.
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
		var previous_height: float = position.y
		position.y = move_toward(
			position.y,
			target_height,
			crouch.transition_speed * delta,
		)
		entity.camera_root.position = position
		# Авторизованная геометрия крепления StaticBody; stored body ведёт его RemoteTransform.
		var belt_delta: float = (position.y - previous_height) * crouch.belt_lowering_ratio
		for mount: Node3D in entity.crouch_mounts:
			if is_instance_valid(mount):
				mount.position.y += belt_delta
