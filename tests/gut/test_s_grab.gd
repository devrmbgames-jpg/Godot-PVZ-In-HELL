extends GutTest
## Проверяет весь конвейер хвата: живое владение, физический solver, ввод, инструменты и толкание.


## Подменяет только границу захвата курсора, недоступную у headless DisplayServer.
class CapturedInput extends S_PlayerInput:
	func _accepts_input() -> bool:
		return true


	## Подаёт реальное событие штатному обработчику, минуя только захват курсора ОС.
	func feed_event(event: InputEvent) -> void:
		_unhandled_input(event)


func _mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	return event


## Всегда доступный инструмент считает реально выбранные действия руки.
class ProbeAction extends DEF_InteractionAction:
	## Число вызовов execute после разрешения приоритетов ввода.
	var calls: int = 0


	## Разрешает действие; ограничения накладывает общий resolver ввода.
	func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		return true


	## Учитывает одно исполнение без побочного игрового эффекта.
	func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
		calls += 1


## Изолированный World текущего физического теста.
var grab_world: World
## Живой владелец тестовых слотов и ввода.
var holder_entity: Entity
## Игровая сущность удерживаемой коробки.
var box_entity: Entity
## Физическое тело владельца; его параметры задаёт тест.
var holder_body: RigidBody3D
## Физическое тело коробки, исполняющее силы solver.
var box_body: RigidBody3D
## Снимок ввода текущего тестового участника.
var input_state: C_Controller
## Производные кеши хвата и токены управления.
var grab_control: C_GrabControl
## Производное состояние массы переносимого груза.
var carry_load: C_CarryLoad


#region Тестовое окружение и устойчивость жидкостей
## Жидкость выпрямляется независимо от наклона камеры, сохраняя ручной поворот по Y.
func test_held_liquid_rights_itself_and_stays_upright_when_camera_tilts() -> void:
	box_entity.add_component(C_LiquidTilt.new())
	box_body.rotation = Vector3(1.2, 0.4, 0.2)
	for frame: int in 2:
		await get_tree().physics_frame
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	var anchor: Node3D = GrabService.slot_anchor(holder_entity, C_Grabbable.HoldSlot.CARRY)
	anchor.rotation = Vector3(-0.9, 0.65, 0.0)
	for frame: int in 50:
		await get_tree().physics_frame
	assert_gt(box_body.global_basis.y.normalized().dot(Vector3.UP), 0.99, "Liquid stands upright despite the tilted carry anchor")

	var profile: GrabControlProfile = GrabService.profile_for(box_entity)
	assert_eq(profile.rotation_axis, C_Grabbable.RotationAxis.Y_ONLY, "Manual yaw remains available")
	assert_eq(profile.max_rotation_speed, 3.0)
	GrabService.release(holder_entity, box_entity)
	assert_null(GrabService.held_relationship(box_entity))


## Обычный предмет следует наклону опоры; политика жидкости может явно отключить выпрямление.
func test_regular_prop_keeps_free_rotation_when_held_and_liquid_policy_can_opt_out() -> void:
	for frame: int in 2:
		await get_tree().physics_frame
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	var anchor: Node3D = GrabService.slot_anchor(holder_entity, C_Grabbable.HoldSlot.CARRY)
	anchor.rotation.x = 0.7
	for frame: int in 12:
		await get_tree().physics_frame
	assert_lt(box_body.global_basis.y.normalized().dot(Vector3.UP), 0.9, "Ordinary prop follows manual/camera pitch")
	assert_false(GrabService.profile_for(box_entity).keep_upright)

	var liquid: C_LiquidTilt = C_LiquidTilt.new()
	liquid.keep_upright_while_held = false
	box_entity.add_component(liquid)
	assert_false(GrabService.profile_for(box_entity).keep_upright)


## Создаёт физического владельца и коробку в отдельном World с observers хвата и толкания.
func before_each() -> void:
	grab_world = World.new()
	add_child(grab_world)
	ECS.world = grab_world
	var observer: O_GrabLifecycle = O_GrabLifecycle.new()
	grab_world.add_observer(observer)
	grab_world.add_observer(O_PushLifecycle.new())
	holder_entity = make_holder(Vector3.ZERO)
	box_entity = make_box(Vector3(0.0, 1.0, -1.5))
	holder_body = holder_entity as Node as RigidBody3D
	box_body = box_entity as Node as RigidBody3D
	input_state = holder_entity.get_component(C_Controller) as C_Controller
	grab_control = holder_entity.get_component(C_GrabControl) as C_GrabControl
	carry_load = holder_entity.get_component(C_CarryLoad) as C_CarryLoad

	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	interactor.target = box_entity
	interactor.physics_target = box_body


## Освобождает живые связи и удаляет тестовый World, исключая оставшиеся ссылки ECS.
func after_each() -> void:
	var remaining: Array[Entity] = grab_world.entities.duplicate()
	for actor: Entity in remaining:
		if is_instance_valid(actor):
			PushService.entity_unavailable(actor)
			GrabService.entity_unavailable(actor)
	grab_world.entities = grab_world.entities.filter(func(entity: Variant) -> bool: return is_instance_valid(entity))
	grab_world.purge(false)
	grab_world.free()
	ECS.world = null


func _apply_player_intent() -> void:
	var intent_system: S_PlayerIntent = S_PlayerIntent.new()
	intent_system.process([holder_entity], [[input_state]], 0.0)
	intent_system.free()


## Создаёт физического участника с тестовыми опорами рук, лучом и компонентами ввода.
func make_holder(location: Vector3) -> Entity:
	var rigid: RigidBody3D = RigidBody3D.new()
	rigid.set_script(E_RigidBodyCharacter)
	rigid.position = location
	rigid.freeze = true
	var actor: Entity = rigid as Node as Entity
	var origin: Marker3D = Marker3D.new()
	origin.position.y = 1.0
	rigid.add_child(origin)

	var right_hand: Marker3D = Marker3D.new()
	right_hand.position = Vector3(0.35, 1.0, -0.5)
	rigid.add_child(right_hand)
	var left_hand: Marker3D = Marker3D.new()
	left_hand.position = Vector3(-0.35, 1.0, -0.5)
	rigid.add_child(left_hand)
	var lowered_right_hand: Marker3D = Marker3D.new()
	lowered_right_hand.position = Vector3(0.35, -0.5, 0.25)
	rigid.add_child(lowered_right_hand)

	var lowered_left_hand: Marker3D = Marker3D.new()
	lowered_left_hand.position = Vector3(-0.35, -0.5, 0.25)
	rigid.add_child(lowered_left_hand)
	var interaction_ray: RayCast3D = RayCast3D.new()
	interaction_ray.position.y = 1.0
	interaction_ray.target_position = Vector3(0.0, 0.0, -3.0)
	interaction_ray.enabled = true
	rigid.add_child(interaction_ray)
	actor.set("interaction_ray_cast", interaction_ray)
	actor.set("hold_anchor", origin)
	actor.set("right_hand_slot", right_hand)
	actor.set("left_hand_slot", left_hand)
	actor.set("lowered_right_hand_slot", lowered_right_hand)
	actor.set("lowered_left_hand_slot", lowered_left_hand)
	actor.component_resources = [
		C_Controller.new(),
		C_Interactor.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
		C_PushControl.new(),
	]
	grab_world.add_entity(actor)
	return actor


## Создаёт динамическую коробку массой 5 кг с игровым компонентом хвата.
func make_box(location: Vector3) -> Entity:
	var rigid: RigidBody3D = RigidBody3D.new()
	rigid.set_script(E_GrabbableBody)
	rigid.position = location
	rigid.gravity_scale = 0.0
	rigid.mass = 5.0
	rigid.continuous_cd = true
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape_resource: BoxShape3D = BoxShape3D.new()
	shape_resource.size = Vector3.ONE * 0.6
	shape_node.shape = shape_resource
	rigid.add_child(shape_node)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "BoxMesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE * 0.6
	mesh_instance.mesh = box_mesh
	rigid.add_child(mesh_instance)
	var actor: Entity = rigid as Node as Entity
	var config: C_Grabbable = C_Grabbable.new()
	actor.component_resources = [C_Interactable.new(), config]
	grab_world.add_entity(actor)
	return actor


## Создаёт физическое тело без игрового скрипта; масса задаётся в килограммах.
func make_raw_rigid_body(location: Vector3, mass: float = 5.0) -> RigidBody3D:
	var scene: PackedScene = load("res://tests/fixtures/raw_rigid_body.tscn") as PackedScene
	var body: RigidBody3D = scene.instantiate() as RigidBody3D
	body.position = location
	body.mass = mass
	grab_world.add_child(body)
	return body


func _grabbable(entity: Entity) -> C_Grabbable:
	return entity.get_component(C_Grabbable) as C_Grabbable


func _add_external_grip(held: Entity, slot_index: C_Grabbable.HoldSlot) -> void:
	var grip_data: R_HeldBy = R_HeldBy.new()
	grip_data.slot = slot_index
	held.add_relationship(Relationship.new(grip_data, holder_entity))
#endregion


#region Чернила, переходы хвата и подсветка
## Чернила хранятся локально и разрывают штрих при смене грани или пропуске поверхности.
func test_marker_samples_follow_package_transform_and_split_faces() -> void:
	box_entity.add_component(C_PackageState.new())
	box_entity.add_component(C_PackageMarks.new())
	var marker: C_Marker = C_Marker.new()
	box_body.rotation = Vector3(0.2, 0.6, -0.1)
	var local_point: Vector3 = Vector3(0.1, 0.3, 0.0)
	var normal: Vector3 = box_body.global_basis * Vector3.UP
	PackageMarkService.append_sample(marker, box_entity, box_body.to_global(local_point), normal)

	var marks: C_PackageMarks = box_entity.get_component(C_PackageMarks) as C_PackageMarks
	assert_eq(marks.point_count, 1)
	assert_almost_eq(
		marks.strokes[0].points[0],
		local_point + Vector3.UP * PackageMarkService.SURFACE_OFFSET,
		Vector3.ONE * 0.0001,
	)
	var saved: Vector3 = marks.strokes[0].points[0]
	box_body.position += Vector3(2.0, 0.0, 0.0)
	box_body.rotate_y(0.5)
	assert_eq(marks.strokes[0].points[0], saved)
	assert_almost_eq(marks.strokes[0].normal, Vector3.UP, Vector3.ONE * 0.0001)

	PackageMarkService.append_sample(
		marker,
		box_entity,
		box_body.to_global(Vector3(0.1, 0.3, 0.0)),
		box_body.global_basis * Vector3.RIGHT,
	)
	assert_eq(marks.strokes.size(), 2, "Different faces must not be joined across an edge")
	PackageMarkService.break_stroke(marker)
	PackageMarkService.append_sample(
		marker,
		box_entity,
		box_body.to_global(local_point),
		box_body.global_basis * Vector3.UP,
	)
	assert_eq(marks.strokes.size(), 3, "A miss or button release must split continuity")


## Лимит точек ограничивает чернила; разрушенная коробка очищает и не принимает новые штрихи.
func test_marker_marks_are_bounded_and_destroyed_packages_reject_ink() -> void:
	box_entity.add_component(C_PackageState.new())
	box_entity.add_component(C_PackageMarks.new())
	var marker: C_Marker = C_Marker.new()
	marker.max_package_points = 2
	for index: int in 3:
		PackageMarkService.append_sample(
			marker,
			box_entity,
			box_body.to_global(Vector3(index * 0.02, 0.3, 0.0)),
			Vector3.UP,
		)

	var marks: C_PackageMarks = box_entity.get_component(C_PackageMarks) as C_PackageMarks
	assert_eq(marks.point_count, 2)
	var state: C_PackageState = box_entity.get_component(C_PackageState) as C_PackageState
	state.damage = C_PackageState.Damage.DESTROYED
	PackageMarkService.clear_marks(box_entity)
	assert_eq(marks.point_count, 0)
	assert_true(marks.strokes.is_empty())
	PackageMarkService.append_sample(marker, box_entity, Vector3.ZERO, Vector3.UP)
	assert_eq(marks.point_count, 0)
	assert_null(marker.stroke)


## Scheduled pointer continuation consumes each captured input tick exactly once.
func test_marker_manual_flush_consumes_pointer_delta_once_per_input_tick() -> void:
	_grabbable(box_entity).allowed_hand_slots = 6
	assert_true(GrabService.try_pickup(holder_entity, box_entity, C_Grabbable.HoldSlot.LEFT_HAND))
	var marker: C_Marker = C_Marker.new()
	box_entity.add_component(marker)
	marker.capture_token = InteractionControlFocus.acquire(holder_entity, box_entity, InteractionControlFocus.Priority.DRAWING)
	marker.pointer = Vector2(100, 100)
	input_state.input_tick = 1
	input_state.look_delta = Vector2(5, 3)
	var owner: S_Marker = S_Marker.new()
	owner.group = "marker_manual"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	grab_world.add_system(owner)
	grab_world.process(0.0, owner.group)
	grab_world.process(0.0, owner.group)
	assert_eq(marker.pointer, Vector2(100, 100))
	grab_world.flush_command_buffers()
	assert_eq(marker.pointer, Vector2(105, 103))
	assert_eq(marker.last_input_tick, 1)
	input_state.input_tick = 2
	grab_world.process(0.0, owner.group)
	input_state.look_delta = Vector2(50, 30)
	grab_world.flush_command_buffers()
	assert_eq(marker.pointer, Vector2(110, 106), "Queued pointer input is immutable")


## A new marker capture cannot inherit the queued continuation from its predecessor.
func test_marker_manual_flush_revalidates_capture_identity() -> void:
	_grabbable(box_entity).allowed_hand_slots = 6
	assert_true(GrabService.try_pickup(holder_entity, box_entity, C_Grabbable.HoldSlot.LEFT_HAND))
	var marker: C_Marker = C_Marker.new()
	box_entity.add_component(marker)
	marker.capture_token = InteractionControlFocus.acquire(holder_entity, box_entity, InteractionControlFocus.Priority.DRAWING)
	marker.pointer = Vector2(100, 100)
	input_state.input_tick = 1
	input_state.look_delta = Vector2(5, 3)
	var owner: S_Marker = S_Marker.new()
	owner.group = "marker_manual"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	grab_world.add_system(owner)
	grab_world.process(0.0, owner.group)
	var previous_token: int = marker.capture_token
	MarkerSessionService.end(box_entity, holder_entity)
	marker.capture_token = InteractionControlFocus.acquire(holder_entity, box_entity, InteractionControlFocus.Priority.DRAWING)
	assert_ne(marker.capture_token, previous_token)
	grab_world.flush_command_buffers()
	assert_eq(marker.pointer, Vector2(100, 100))
	assert_ne(marker.capture_token, 0)
	grab_world.process(0.0, owner.group)
	grab_world.flush_command_buffers()
	assert_eq(marker.pointer, Vector2(105, 103))


## Отмена рисования освобождает только его токен, сохраняя чужой захват и предмет в руке.
func test_marker_cancel_releases_only_its_token_and_preserves_hand() -> void:
	_grabbable(box_entity).allowed_hand_slots = 6
	assert_true(GrabService.try_pickup(holder_entity, box_entity, C_Grabbable.HoldSlot.LEFT_HAND))
	var marker: C_Marker = C_Marker.new()
	box_entity.add_component(marker)
	marker.capture_token = InteractionControlFocus.acquire(
		holder_entity,
		box_entity,
		InteractionControlFocus.Priority.DRAWING,
	)

	var other_owner: RefCounted = RefCounted.new()
	var other_token: int = InteractionControlFocus.acquire(
		holder_entity,
		other_owner,
		InteractionControlFocus.Priority.PUSH,
	)
	input_state.cancel_pressed = true
	InteractionInputFixture.marker(box_entity)
	assert_eq(marker.capture_token, 0)
	assert_eq(InteractionControlFocus.current(holder_entity), InteractionControlFocus.Priority.PUSH)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND), box_entity)
	InteractionControlFocus.release(holder_entity, other_token)
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.HANDS,
	)


## Рисование получает движение мыши без поворота камеры/предмета; выход возвращает обзор.
func test_marker_capture_consumes_mouse_delta_without_camera_or_rotation() -> void:
	var producer: CapturedInput = CapturedInput.new()
	add_child(producer)
	var marker: C_Marker = C_Marker.new()
	marker.capture_token = InteractionControlFocus.acquire(
		holder_entity,
		box_entity,
		InteractionControlFocus.Priority.DRAWING,
	)

	var original_look: Vector3 = input_state.direction_look
	producer.feed_event(_mouse_motion(Vector2(25.0, 15.0)))
	producer.process([holder_entity], [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_eq(input_state.direction_look, original_look)
	assert_eq(input_state.look_delta, Vector2(25.0, 15.0))
	input_state.rotate_held = true
	assert_false(InteractionActionResolver.wants_rotation(holder_entity, input_state))
	MarkerSessionService.end(marker, holder_entity)
	producer.feed_event(_mouse_motion(Vector2(25.0, 15.0)))
	producer.process([holder_entity], [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_ne(input_state.direction_look, original_look, "Look resumes after drawing exits")
	producer.free()


## Ввод взаимодействия меняет живой хват и одновременно обновляет массу и исключения столкновений.
func test_interact_picks_up_and_releases_with_load_and_collision_cleanup() -> void:
	input_state.interact_pressed = true
	InteractionInputFixture.advance(holder_entity)
	assert_eq(GrabService.held_object(holder_entity), box_entity)
	assert_true(carry_load.active)
	assert_eq(carry_load.mass_kg, 5.0)
	assert_true(box_body.get_collision_exceptions().has(holder_body))
	assert_false(box_body.freeze)
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_eq(carry_load.mass_kg, 0.0)
	assert_false(box_body.get_collision_exceptions().has(holder_body))


## Отпускание сохраняет линейную и угловую скорости физического тела.
func test_release_preserves_linear_and_angular_inertia() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	box_body.linear_velocity = Vector3(2.0, 3.0, 4.0)
	box_body.angular_velocity = Vector3(0.0, 2.0, 1.0)
	GrabService.release(holder_entity, box_entity)
	assert_eq(box_body.linear_velocity, Vector3(2.0, 3.0, 4.0))
	assert_eq(box_body.angular_velocity, Vector3(0.0, 2.0, 1.0))


## Бросок сначала освобождает владение и ограничения, затем придаёт скорость.
func test_primary_throws_after_releasing_ownership() -> void:
	for physics_tick: int in 2:
		await get_tree().physics_frame
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	input_state.action_main_pressed = true
	input_state.direction_look = Vector3.FORWARD
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_false(box_body.get_collision_exceptions().has(holder_body))
	for physics_tick: int in 2:
		await get_tree().physics_frame
	assert_lt(box_body.linear_velocity.z, -9.5)


## Основная и вторичная кнопки сами не создают хват при свободных руках.
func test_free_primary_and_secondary_do_not_acquire_object() -> void:
	input_state.action_main_pressed = true
	input_state.action_second_held = true
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_false(grab_control.rotation_active)
	assert_eq(box_body.linear_velocity, Vector3.ZERO)


## Ручной поворот меняет смещение хвата, оставляя тело физике и сохраняя снимок ввода.
func test_rotation_uses_offset_and_preserves_input_and_look() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	input_state.action_second_held = true
	input_state.look_delta = Vector2(30.0, 20.0)
	var initial_look: Vector3 = input_state.direction_look
	var initial_basis: Basis = box_body.basis
	InteractionInputFixture.advance(holder_entity)
	var grip: R_HeldBy = GrabService.held_relationship(box_entity).relation as R_HeldBy
	assert_true(grab_control.rotation_active)
	assert_false(grip.rotation_offset.is_equal_approx(Quaternion.IDENTITY))
	assert_eq(input_state.look_delta, Vector2(30.0, 20.0))
	assert_eq(input_state.direction_look, initial_look)
	assert_eq(box_body.basis, initial_basis)
	input_state.action_second_held = false
	InteractionInputFixture.advance(holder_entity)
	assert_false(grab_control.rotation_active)


## Один слот удерживает один предмет, а предмет имеет одного владельца хвата.
func test_holder_capacity_and_exclusive_ownership() -> void:
	var other_box: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var other_holder: Entity = make_holder(Vector3(1.0, 0.0, 0.0))
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	assert_false(GrabService.try_pickup(holder_entity, other_box))
	assert_false(GrabService.try_pickup(other_holder, box_entity))
	assert_eq(box_entity.relationships.size(), 1)


## Внешнее снятие хвата очищает массу, кеши, режим поворота и исключения столкновений.
func test_external_relationship_removal_restores_runtime_state() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	grab_control.rotation_active = true
	box_entity.remove_relationship(GrabService.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_null(grab_control.held_carry)
	assert_false(box_body.get_collision_exceptions().has(holder_body))


## Внешний Relationship выполняет тот же lifecycle хвата и освобождения.
func test_external_relationship_addition_applies_lifecycle() -> void:
	box_entity.add_relationship(Relationship.new(R_HeldBy.new(), holder_entity))
	assert_eq(GrabService.held_object(holder_entity), box_entity)
	assert_true(carry_load.active)
	GrabService.release(holder_entity, box_entity)
	assert_false(carry_load.active)


## Удаление предмета из World очищает производное состояние владельца.
func test_world_removal_of_held_entity_cleans_up() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	grab_control.rotation_active = true
	grab_world.remove_entity(box_entity)
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_null(grab_control.held_carry)


## Удаление физического предмета освобождает кеш хвата и переноса груза.
func test_deleted_object_cleans_up_holder() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	grab_control.rotation_active = true
	box_entity.queue_free()
	await get_tree().process_frame
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)
	assert_null(grab_control.held_carry)


## Удаление владельца освобождает предмет и исключения столкновений.
func test_deleted_holder_releases_object() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	holder_entity.queue_free()
	await get_tree().process_frame
	assert_null(GrabService.held_relationship(box_entity))
	assert_true(box_body.get_collision_exceptions().is_empty())


## Отключение управления владельца снимает живой хват.
func test_disabled_holder_releases_object() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	grab_world.disable_entity(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_false(carry_load.active)


## Отключённый или слишком далёкий предмет недоступен для захвата.
func test_disabled_or_distant_target_is_rejected() -> void:
	var interactable: C_Interactable = box_entity.get_component(C_Interactable) as C_Interactable
	interactable.enabled = false
	assert_false(GrabService.try_pickup(holder_entity, box_entity))
	interactable.enabled = true
	box_body.position.z = -20.0
	for physics_tick: int in 2:
		await get_tree().physics_frame
	assert_false(GrabService.try_pickup(holder_entity, box_entity))


## Луч выбирает одну текущую цель и восстанавливает прежний overlay после потери наведения.
func test_raycast_selects_and_highlights_only_the_current_target() -> void:
	for physics_tick: int in 2:
		await get_tree().physics_frame
	var targeting: S_InteractionTargeting = S_InteractionTargeting.new()
	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var mesh_instance: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	var previous_overlay: StandardMaterial3D = StandardMaterial3D.new()
	mesh_instance.material_overlay = previous_overlay
	interactor.target = null
	interactor.physics_target = null
	targeting.process([holder_entity], [[interactor]], 0.0)
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(interactor.target, box_entity)
	assert_not_null(mesh_instance.material_overlay)
	assert_ne(mesh_instance.material_overlay, previous_overlay)

	var interaction_ray: RayCast3D = GrabService.interaction_raycast(holder_entity)
	interaction_ray.rotation.y = PI
	targeting.process([holder_entity], [[interactor]], 0.0)
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_null(interactor.target)
	assert_eq(mesh_instance.material_overlay, previous_overlay)
	highlight.free()
	targeting.free()


## Очистка подсветки восстанавливает material_overlay без подмены выбранной цели.
func test_highlight_cleanup_restores_overlay_without_changing_target() -> void:
	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	grab_world.add_system(highlight)
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var mesh_instance: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	var original: StandardMaterial3D = StandardMaterial3D.new()
	mesh_instance.material_overlay = original
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_ne(mesh_instance.material_overlay, original)
	grab_world.remove_system(highlight)
	await get_tree().process_frame
	assert_eq(mesh_instance.material_overlay, original)
	assert_eq(interactor.target, box_entity)


## Общая подсветка живёт до удаления последнего наблюдателя.
func test_shared_highlight_survives_one_holder_removal_and_restores_on_last() -> void:
	var second: Entity = make_holder(Vector3(5.0, 0.0, 0.0))
	var first_interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var second_interactor: C_Interactor = second.get_component(C_Interactor) as C_Interactor
	second_interactor.target = box_entity
	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	grab_world.add_system(highlight)
	var mesh_instance: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	var original: StandardMaterial3D = StandardMaterial3D.new()
	mesh_instance.material_overlay = original
	highlight.process([holder_entity, second], [[first_interactor, second_interactor]], 0.0)

	var selected: Material = mesh_instance.material_overlay
	grab_world.remove_entity(second)
	assert_eq(mesh_instance.material_overlay, selected)
	holder_entity.remove_component(C_Interactor)
	assert_eq(mesh_instance.material_overlay, original)
	assert_eq(first_interactor.target, box_entity)


## Отключённое тело не возвращает подсветку следующим обновлением наведения.
func test_disabled_physical_target_cannot_regain_highlight_on_next_targeting_tick() -> void:
	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	grab_world.add_system(highlight)
	var targeting: S_InteractionTargeting = S_InteractionTargeting.new()
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var mesh_instance: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	var original: StandardMaterial3D = StandardMaterial3D.new()
	mesh_instance.material_overlay = original
	highlight.process([holder_entity], [[interactor]], 0.0)
	grab_world.disable_entity(box_entity)
	assert_eq(mesh_instance.material_overlay, original)
	for physics_tick: int in 2:
		await get_tree().physics_frame
	targeting.process([holder_entity], [[interactor]], 0.0)
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_null(interactor.target)
	assert_eq(mesh_instance.material_overlay, original)
	targeting.free()


## Подсветка той же цели обновляется по массе и авторскому материалу, сохраняя основной материал.
func test_highlight_authored_material_changes_with_weight_on_same_target() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var config: C_Grabbable = box_entity.get_component(C_Grabbable) as C_Grabbable
	config.allowed_hand_slots = 0
	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	grab_world.add_system(highlight)
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var mesh: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	var base: StandardMaterial3D = StandardMaterial3D.new()
	mesh.material_override = base
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(mesh.material_overlay, highlight.available_material)
	assert_true(highlight.available_material.resource_path.ends_with("highlight_available.res"))
	box_body.mass = 200.0
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(mesh.material_overlay, highlight.unavailable_material)

	var custom: StandardMaterial3D = StandardMaterial3D.new()
	highlight.unavailable_material = custom
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(mesh.material_overlay, custom, "An authored replacement is used without changing the target")
	assert_eq(mesh.material_override, base)
	box_body.mass = 5.0
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(mesh.material_overlay, highlight.available_material)
	grab_world.remove_system(highlight)
	await get_tree().process_frame
	assert_null(mesh.material_overlay)


## Несколько наблюдателей разрешают материал подсветки с устойчивым приоритетом.
func test_highlight_multi_holder_material_priority_and_removal_are_deterministic() -> void:
	var second: Entity = make_holder(Vector3.ZERO)
	var first_interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var second_interactor: C_Interactor = second.get_component(C_Interactor) as C_Interactor
	second_interactor.target = box_entity
	second_interactor.physics_target = box_body
	var token: int = InteractionControlFocus.acquire(second, self, InteractionControlFocus.Priority.PROLONGED)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	grab_world.add_system(highlight)
	var mesh: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	highlight.process([second, holder_entity], [[second_interactor, first_interactor]], 0.0)
	assert_eq(mesh.material_overlay, highlight.available_material)
	highlight.process([holder_entity, second], [[first_interactor, second_interactor]], 0.0)
	assert_eq(mesh.material_overlay, highlight.available_material)
	grab_world.remove_entity(holder_entity)
	assert_eq(mesh.material_overlay, highlight.busy_material)
	InteractionControlFocus.release(second, token)
	second.remove_component(C_Interactor)
	assert_null(mesh.material_overlay)


## Модальный ввод убирает и возвращает подсветку без обязательной смены цели.
func test_highlight_modal_clears_and_restores_without_target_change() -> void:
	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	grab_world.add_system(highlight)
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var mesh: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	var original: StandardMaterial3D = StandardMaterial3D.new()
	mesh.material_overlay = original
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_ne(mesh.material_overlay, original)

	var token: int = InteractionControlFocus.acquire(holder_entity, self, InteractionControlFocus.Priority.MODAL)
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(mesh.material_overlay, original)
	InteractionControlFocus.release(holder_entity, token)
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_ne(mesh.material_overlay, original)
	grab_world.remove_system(highlight)
	await get_tree().process_frame
	assert_eq(mesh.material_overlay, original)


## Подсветка не затирает overlay другой обратной связи взаимодействия.
func test_highlight_yields_to_other_interaction_overlay_and_does_not_erase_it() -> void:
	var highlight: S_InteractionHighlight = S_InteractionHighlight.new()
	grab_world.add_system(highlight)
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var mesh: MeshInstance3D = box_body.get_node("BoxMesh") as MeshInstance3D
	highlight.process([holder_entity], [[interactor]], 0.0)
	var feedback: StandardMaterial3D = StandardMaterial3D.new()
	mesh.material_overlay = feedback
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(mesh.material_overlay, feedback)
	interactor.target = null
	interactor.physics_target = null
	highlight.process([holder_entity], [[interactor]], 0.0)
	assert_eq(mesh.material_overlay, feedback)
	grab_world.remove_system(highlight)
	await get_tree().process_frame
	assert_eq(mesh.material_overlay, feedback)


## Скорость переноса линейно зависит от массы и текущей силы владельца.
func test_carry_speed_is_linear_from_mass_and_current_strength() -> void:
	var motion: C_Motion = C_Motion.new()
	var strength: C_Strength = holder_entity.get_component(C_Strength) as C_Strength
	assert_not_null(strength)
	assert_eq(strength.base, 1.0)
	assert_eq(strength.value, 1.0)
	assert_eq(CarryLoadPolicy.minimum_mass_kg(strength), 30.0)
	assert_eq(CarryLoadPolicy.maximum_mass_kg(strength), 120.0)
	assert_eq(CarryLoadPolicy.mobility_multiplier(30.0, strength), 1.0)
	assert_almost_eq(CarryLoadPolicy.mobility_multiplier(75.0, strength), 0.5, 0.001)
	assert_eq(CarryLoadPolicy.mobility_multiplier(120.0, strength), 0.0)
	assert_true(CarryLoadPolicy.can_carry(120.0, strength))
	assert_false(CarryLoadPolicy.can_carry(120.01, strength))

	box_body.mass = 75.0
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	assert_eq(carry_load.mass_kg, 75.0)
	assert_almost_eq(CharacterMotionSolver.effective_speed(motion, carry_load, strength), 3.0, 0.001)
	assert_eq(motion.max_speed, 6.0)
	assert_eq(motion.ground_acceleration, 25.0)

	strength.value = 2.0
	assert_eq(CarryLoadPolicy.minimum_mass_kg(strength), 50.0)
	assert_eq(CarryLoadPolicy.maximum_mass_kg(strength), 150.0)
	assert_almost_eq(CharacterMotionSolver.effective_speed(motion, carry_load, strength), 4.5, 0.001)

	GrabService.release(holder_entity, box_entity)
	assert_eq(carry_load.mass_kg, 0.0)
	assert_eq(CharacterMotionSolver.effective_speed(motion, carry_load, strength), 6.0)


## Коэффициент тяжёлого груза уменьшает обзор, ручной поворот и скорость броска.
func test_carry_mobility_scales_camera_manual_rotation_and_throw_velocity() -> void:
	var strength: C_Strength = holder_entity.get_component(C_Strength) as C_Strength
	box_body.mass = 75.0
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	assert_almost_eq(CarryLoadPolicy.active_multiplier(carry_load, strength), 0.5, 0.001)
	assert_almost_eq(
		CarryLoadPolicy.scaled_value(10.0, carry_load, strength),
		5.0,
		0.001,
	)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var input_system: CapturedInput = CapturedInput.new()
	add_child(input_system)
	var holders: Array[Entity] = [holder_entity]
	input_state.direction_look = Vector3.FORWARD
	input_system.feed_event(_mouse_motion(Vector2(100.0, 0.0)))
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_almost_eq(
		Vector3.FORWARD.angle_to(input_state.direction_look),
		0.1,
		0.001,
	)

	input_state.action_second_held = true
	input_state.input_tick += 1
	input_state.look_delta = Vector2(100.0, 0.0)
	InteractionInputFixture.advance(holder_entity)
	var grip: R_HeldBy = GrabService.held_relationship(box_entity).relation as R_HeldBy
	assert_almost_eq(absf(grip.rotation_offset.get_euler().y), 0.3, 0.001)

	input_state.action_second_held = false
	input_state.action_main_pressed = true
	input_state.direction_look = Vector3.FORWARD
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	for physics_tick: int in 2:
		await get_tree().physics_frame
	assert_almost_eq(box_body.linear_velocity.z, -5.0, 0.15)

	input_system.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Предельная масса даёт нулевой коэффициент активного управления грузом.
func test_maximum_carry_mass_has_zero_look_rotation_and_throw_control() -> void:
	var strength: C_Strength = holder_entity.get_component(C_Strength) as C_Strength
	carry_load.active = true
	carry_load.mass_kg = 120.0
	assert_eq(CarryLoadPolicy.active_multiplier(carry_load, strength), 0.0)
	assert_eq(CarryLoadPolicy.scaled_value(10.0, carry_load, strength), 0.0)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var input_system: CapturedInput = CapturedInput.new()
	add_child(input_system)
	var holders: Array[Entity] = [holder_entity]
	input_state.direction_look = Vector3.FORWARD
	input_system.feed_event(_mouse_motion(Vector2(200.0, 100.0)))
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_eq(input_state.direction_look, Vector3.FORWARD)
	input_system.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	carry_load.active = false
	carry_load.mass_kg = 0.0
#endregion


#region Владение слотами
## Перенос груза и обе руки имеют независимых живых владельцев слотов.
func test_holder_can_hold_carry_and_both_hand_slots() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	_add_external_grip(box_entity, C_Grabbable.HoldSlot.CARRY)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY), box_entity)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND), left_item)
	assert_true(carry_load.active)


## Отпускание инструмента в руке сохраняет груз и его массу.
func test_releasing_hand_item_preserves_carry_load_and_cache() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_add_external_grip(box_entity, C_Grabbable.HoldSlot.CARRY)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	GrabService.release(holder_entity, right_item)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY), box_entity)
	assert_true(carry_load.active)
	assert_eq(carry_load.mass_kg, 5.0)


## Отключение владельца освобождает сразу все три слота и производные кеши.
func test_disabled_holder_releases_all_slot_relationships() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	_add_external_grip(box_entity, C_Grabbable.HoldSlot.CARRY)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	grab_world.disable_entity(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_null(GrabService.held_relationship(right_item))
	assert_null(GrabService.held_relationship(left_item))
	assert_false(carry_load.active)
	assert_null(grab_control.held_carry)
	assert_null(grab_control.held_right)
	assert_null(grab_control.held_left)


## Недопустимое внешнее назначение слота не оставляет лишний хват.
func test_external_invalid_or_duplicate_slot_relationship_is_rejected() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var second_right_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(second_right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_add_external_grip(box_entity, C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND))
	assert_false(carry_load.active)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(second_right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND))


## Неуспешная замена предмета в руке сохраняет прежнего владельца слота.
func test_failed_hand_replacement_keeps_existing_occupant() -> void:
	var occupant: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var frozen_target: Entity = make_box(Vector3(0.0, 1.0, -1.5))
	var distant_target: Entity = make_box(Vector3(0.0, 1.0, -20.0))
	_grabbable(occupant).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(frozen_target).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(distant_target).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_add_external_grip(occupant, C_Grabbable.HoldSlot.RIGHT_HAND)
	(frozen_target as Node as RigidBody3D).freeze = true
	assert_false(
		GrabService.try_pickup(holder_entity, frozen_target, C_Grabbable.HoldSlot.RIGHT_HAND, true)
	)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), occupant)
	assert_false(
		GrabService.try_pickup(holder_entity, distant_target, C_Grabbable.HoldSlot.RIGHT_HAND, true)
	)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), occupant)


## Авторская политика выбирает сброс либо сохранение относительного поворота при захвате.
func test_hand_pickup_rotation_reset_and_relative_offset() -> void:
	var config: C_Grabbable = _grabbable(box_entity)
	config.allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	var right_anchor: Node3D = holder_entity.get("right_hand_slot") as Node3D
	right_anchor.global_basis = Basis(Vector3.UP, PI * 0.25)
	box_body.global_basis = Basis(Vector3.UP, PI * 0.75)
	config.reset_rotation_on_pickup = true
	assert_true(GrabService.try_pickup(holder_entity, box_entity, C_Grabbable.HoldSlot.RIGHT_HAND))

	var reset_grip: R_HeldBy = GrabService.held_relationship(box_entity).relation as R_HeldBy
	assert_eq(reset_grip.rotation_offset, Quaternion.IDENTITY)
	GrabService.release(holder_entity, box_entity)
	config.reset_rotation_on_pickup = false
	var expected_offset: Quaternion = (
		right_anchor.global_basis.orthonormalized().get_rotation_quaternion().inverse()
		* box_body.global_basis.orthonormalized().get_rotation_quaternion()
	).normalized()
	assert_true(GrabService.try_pickup(holder_entity, box_entity, C_Grabbable.HoldSlot.RIGHT_HAND))

	var relative_grip: R_HeldBy = GrabService.held_relationship(box_entity).relation as R_HeldBy
	assert_true(relative_grip.rotation_offset.is_equal_approx(expected_offset))
#endregion


#region Ввод слотов и захват управления
## Выбор слота учитывает допустимые руки и настройку смены управления.
func test_pickup_slot_selection_accounts_for_hands_and_swap_mapping() -> void:
	var hand_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	_grabbable(hand_item).allowed_hand_slots = (
		(1 << C_Grabbable.HoldSlot.RIGHT_HAND) | (1 << C_Grabbable.HoldSlot.LEFT_HAND)
	)
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, false), C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, true), -1)
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, false), C_Grabbable.HoldSlot.LEFT_HAND)
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, true), C_Grabbable.HoldSlot.RIGHT_HAND)

	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, false), C_Grabbable.HoldSlot.RIGHT_HAND)
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, true), C_Grabbable.HoldSlot.LEFT_HAND)
	grab_control.swap_hand_controls = true
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, false), C_Grabbable.HoldSlot.LEFT_HAND)
	assert_eq(GrabService.pickup_slot(holder_entity, hand_item, true), C_Grabbable.HoldSlot.RIGHT_HAND)


## Вложенные токены удерживают руки опущенными до отпускания последнего владельца.
func test_nested_capture_lowers_hands_until_last_owner_releases() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	var push_owner: RefCounted = RefCounted.new()
	var modal_owner: RefCounted = RefCounted.new()
	var push_token: int = InteractionControlFocus.acquire(
		holder_entity,
		push_owner,
		InteractionControlFocus.Priority.PUSH,
	)

	var modal_token: int = InteractionControlFocus.acquire(
		holder_entity,
		modal_owner,
		InteractionControlFocus.Priority.MODAL,
	)
	assert_eq(
		GrabService.slot_anchor(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND),
		holder_entity.get("lowered_right_hand_slot"),
	)
	InteractionControlFocus.release(holder_entity, modal_token)
	assert_eq(InteractionControlFocus.current(holder_entity), InteractionControlFocus.Priority.PUSH)
	assert_eq(
		GrabService.slot_anchor(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND),
		holder_entity.get("lowered_left_hand_slot"),
	)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND), left_item)
	InteractionControlFocus.release(holder_entity, push_token)
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.HANDS,
	)
	assert_eq(
		GrabService.slot_anchor(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND),
		holder_entity.get("right_hand_slot"),
	)


## Основное действие направляется в назначенную руку и учитывает смену кнопок.
func test_primary_action_routes_to_mapped_hand_and_swap() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	var right_action: ProbeAction = ProbeAction.new()
	right_action.slot = DEF_InteractionAction.Slot.PRIMARY
	var left_action: ProbeAction = ProbeAction.new()
	left_action.slot = DEF_InteractionAction.Slot.PRIMARY

	var right_actions: C_InteractionActionSet = C_InteractionActionSet.new()
	right_actions.actions = [right_action]
	var left_actions: C_InteractionActionSet = C_InteractionActionSet.new()
	left_actions.actions = [left_action]
	right_item.add_component(right_actions)
	left_item.add_component(left_actions)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	input_state.input_tick += 1
	input_state.action_main_pressed = true
	InteractionInputFixture.advance(holder_entity)
	assert_eq(right_action.calls, 1)
	assert_eq(left_action.calls, 0)
	grab_control.swap_hand_controls = true
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_eq(right_action.calls, 1)
	assert_eq(left_action.calls, 1)


## Захват с более высоким приоритетом блокирует использование, бросок и поворот инструмента.
func test_capture_blocks_hand_use_throw_and_rotation() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	var action: ProbeAction = ProbeAction.new()
	action.slot = DEF_InteractionAction.Slot.PRIMARY
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [action]
	right_item.add_component(actions)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)

	var modal_owner: RefCounted = RefCounted.new()
	var modal_token: int = InteractionControlFocus.acquire(
		holder_entity,
		modal_owner,
		InteractionControlFocus.Priority.MODAL,
	)
	input_state.input_tick += 1
	input_state.action_main_pressed = true
	input_state.physical_override = false
	input_state.rotate_held = true
	InteractionInputFixture.advance(holder_entity)
	assert_eq(action.calls, 0)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	assert_false(grab_control.rotation_active)
	input_state.input_tick += 1
	input_state.physical_override = true
	InteractionInputFixture.advance(holder_entity)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	InteractionControlFocus.release(holder_entity, modal_token)


## Короткий бросок выбирает слот по приоритету; длинное удержание запрашивает контекстный выбор.
func test_drop_priority_and_long_press_placeholder() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	_add_external_grip(box_entity, C_Grabbable.HoldSlot.CARRY)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	input_state.input_tick += 1
	input_state.drop_pressed = true
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY))
	assert_not_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND))
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND))
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND))
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	input_state.drop_pressed = false
	input_state.drop_long_pressed = true
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_true(grab_control.context_wheel_requested)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)


## Пауза очищает отслеживание броска, накопленную мышь и ожидающие действия.
func test_pause_cancels_drop_tracking_and_pending_mouse_and_interaction() -> void:
	var input_system: CapturedInput = CapturedInput.new()
	input_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(input_system)
	holder_entity.add_component(C_PlayerInputController.new())
	var holders: Array[Entity] = [holder_entity]
	var press: InputEventAction = InputEventAction.new()
	press.action = &"drop"
	press.pressed = true
	input_system.feed_event(press)
	input_system.process(holders, [[input_state]], 0.1)
	assert_true(input_state.drop_tracking)
	input_system.feed_event(_mouse_motion(Vector2(100, 40)))
	press = InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	input_system.feed_event(press)
	get_tree().paused = true
	get_tree().paused = false
	assert_false(input_state.drop_tracking)
	input_system.process(holders, [[input_state]], grab_control.drop_long_press_seconds)
	assert_false(input_state.drop_long_pressed)
	assert_false(input_state.drop_pressed)
	assert_false(input_state.interact_pressed)
	assert_eq(input_state.look_delta, Vector2.ZERO)
	input_system.free()


## После длинного удержания отпускание не создаёт дополнительный короткий бросок.
func test_drop_long_press_input_does_not_emit_short_drop_on_release() -> void:
	var input_system: CapturedInput = CapturedInput.new()
	var holders: Array[Entity] = [holder_entity]
	var press_event: InputEventAction = InputEventAction.new()
	press_event.action = &"drop"
	press_event.pressed = true
	input_system.feed_event(press_event)
	input_system.process(holders, [[input_state]], grab_control.drop_long_press_seconds)
	assert_true(input_state.drop_long_pressed)
	assert_false(input_state.drop_pressed)

	var release_event: InputEventAction = InputEventAction.new()
	release_event.action = &"drop"
	release_event.pressed = false
	input_system.feed_event(release_event)
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_false(input_state.drop_long_pressed)
	assert_false(input_state.drop_pressed)
	input_system.free()


## Модификатор поворота работает для обычного предмета без действия инструмента.
func test_generic_hand_rotation_uses_rotate_modifier_without_hand_action() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	input_state.input_tick += 1
	input_state.rotate_held = true
	input_state.look_delta = Vector2(30.0, 20.0)
	InteractionInputFixture.advance(holder_entity)

	var grip: R_HeldBy = GrabService.held_relationship(right_item).relation as R_HeldBy
	assert_true(grab_control.rotation_active)
	assert_false(grip.rotation_offset.is_equal_approx(Quaternion.IDENTITY))


## Разные токены одного владельца освобождаются независимо.
func test_same_owner_captures_release_independently() -> void:
	var owner: RefCounted = RefCounted.new()
	var push_token: int = InteractionControlFocus.acquire(
		holder_entity,
		owner,
		InteractionControlFocus.Priority.PUSH,
	)
	var modal_token: int = InteractionControlFocus.acquire(
		holder_entity,
		owner,
		InteractionControlFocus.Priority.MODAL,
	)
	assert_ne(push_token, modal_token)
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.MODAL,
	)
	InteractionControlFocus.release(holder_entity, modal_token)
	assert_eq(InteractionControlFocus.current(holder_entity), InteractionControlFocus.Priority.PUSH)
	InteractionControlFocus.release(holder_entity, push_token)
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.HANDS,
	)


## Удалённый владелец токена не оставляет захват управления.
func test_destroyed_capture_owner_is_pruned() -> void:
	var owner: RefCounted = RefCounted.new()
	var token: int = InteractionControlFocus.acquire(
		holder_entity,
		owner,
		InteractionControlFocus.Priority.MODAL,
	)
	assert_ne(token, 0)
	owner = null
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.HANDS,
	)
	assert_true(grab_control.captures.is_empty())


## Переход к опущенной опоре и обратно сохраняет хват с предусмотренным допуском восстановления.
func test_hand_grip_survives_lowered_anchor_and_restore_grace() -> void:
	var normal_anchor: Node3D = holder_entity.get("right_hand_slot") as Node3D
	var right_item: Entity = make_box(normal_anchor.global_position)
	var config: C_Grabbable = _grabbable(right_item)
	config.allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	config.break_distance = 0.5
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	await get_tree().physics_frame
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)

	var owner: RefCounted = RefCounted.new()
	var token: int = InteractionControlFocus.acquire(
		holder_entity,
		owner,
		InteractionControlFocus.Priority.MODAL,
	)
	for physics_tick: int in 3:
		await get_tree().physics_frame
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	assert_eq(
		GrabService.slot_anchor(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND),
		holder_entity.get("lowered_right_hand_slot"),
	)
	InteractionControlFocus.release(holder_entity, token)
	assert_eq(
		GrabService.slot_anchor(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND),
		holder_entity.get("right_hand_slot"),
	)
	await get_tree().physics_frame
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)


## Такт броска груза не передаёт вторичную кнопку инструменту в руке.
func test_carry_throw_does_not_route_secondary_input_to_hand_item() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	var action: ProbeAction = ProbeAction.new()
	action.slot = DEF_InteractionAction.Slot.PRIMARY
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [action]
	right_item.add_component(actions)
	_add_external_grip(box_entity, C_Grabbable.HoldSlot.CARRY)
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	input_state.input_tick += 1
	input_state.action_main_pressed = true
	input_state.action_second_pressed = true
	input_state.action_second_held = true
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY))
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	assert_eq(action.calls, 0)


## Политика поворота ограничивает движение осью Y либо полностью отключает его.
func test_y_only_rotation_and_disabled_rotation_policy() -> void:
	var y_only_offset: Quaternion = GrabPhysicsSolver.rotated_offset(
		Quaternion.IDENTITY,
		Vector2(30.0, 20.0),
		C_Grabbable.RotationAxis.Y_ONLY,
	)
	var y_only_euler: Vector3 = y_only_offset.get_euler()
	assert_almost_eq(y_only_euler.x, 0.0, 0.00001)
	assert_almost_eq(y_only_euler.z, 0.0, 0.00001)
	assert_ne(y_only_euler.y, 0.0)

	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var config: C_Grabbable = _grabbable(right_item)
	config.allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	config.manual_rotation_enabled = false
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	input_state.input_tick += 1
	input_state.rotate_held = true
	input_state.look_delta = Vector2(30.0, 20.0)
	InteractionInputFixture.advance(holder_entity)
	assert_false(grab_control.rotation_active)


## Замена в основной руке происходит после проверки реальной видимости предмета.
func test_interact_replaces_primary_hand_after_los_validation() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(box_entity).allowed_hand_slots = (
		(1 << C_Grabbable.HoldSlot.RIGHT_HAND) | (1 << C_Grabbable.HoldSlot.LEFT_HAND)
	)
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	for physics_tick: int in 2:
		await get_tree().physics_frame

	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingGeometry.find_target(holder_entity, interactor)
	interactor.physics_target = InteractionTargetingGeometry.find_physics_target(holder_entity, interactor)
	assert_eq(interactor.target, box_entity)
	assert_eq(interactor.physics_target, box_body)
	input_state.input_tick += 1
	input_state.interact_pressed = true
	InteractionInputFixture.advance(holder_entity)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), box_entity)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND), left_item)
	assert_null(GrabService.held_relationship(right_item))


## Замена во второй руке сохраняет предмет основной руки и требует видимости.
func test_use_replaces_secondary_hand_after_los_validation() -> void:
	var right_item: Entity = make_box(Vector3(1.0, 1.0, -1.5))
	var left_item: Entity = make_box(Vector3(-1.0, 1.0, -1.5))
	_grabbable(box_entity).allowed_hand_slots = (
		(1 << C_Grabbable.HoldSlot.RIGHT_HAND) | (1 << C_Grabbable.HoldSlot.LEFT_HAND)
	)
	_grabbable(right_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.RIGHT_HAND
	_grabbable(left_item).allowed_hand_slots = 1 << C_Grabbable.HoldSlot.LEFT_HAND
	_add_external_grip(right_item, C_Grabbable.HoldSlot.RIGHT_HAND)
	_add_external_grip(left_item, C_Grabbable.HoldSlot.LEFT_HAND)
	for physics_tick: int in 2:
		await get_tree().physics_frame

	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingGeometry.find_target(holder_entity, interactor)
	interactor.physics_target = InteractionTargetingGeometry.find_physics_target(holder_entity, interactor)
	assert_eq(interactor.target, box_entity)
	assert_eq(interactor.physics_target, box_body)
	input_state.input_tick += 1
	input_state.use_pressed = true
	InteractionInputFixture.advance(holder_entity)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), right_item)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.LEFT_HAND), box_entity)
	assert_null(GrabService.held_relationship(left_item))
#endregion


#region Математика solver
## Сила удержания компенсирует тяжесть и ограничивается авторским максимумом.
func test_position_force_compensates_gravity_and_is_bounded() -> void:
	var config: C_Grabbable = C_Grabbable.new()
	var gravity: Vector3 = Vector3(0.0, -10.0, 0.0)
	assert_eq(
		GrabPhysicsSolver.position_force(Vector3.ZERO, Vector3.ZERO, gravity, 5.0, GrabControlProfile.from_grabbable(config)),
		Vector3(0.0, 50.0, 0.0),
	)
	var force: Vector3 = GrabPhysicsSolver.position_force(
		Vector3.ONE * 100.0,
		Vector3.ZERO,
		gravity,
		80.0,
		GrabControlProfile.from_grabbable(config),
	)
	assert_almost_eq(force.length(), config.max_hold_force, 0.001)


## Поворот использует короткую дугу и не оставляет угловую скорость у достигнутой цели.
func test_rotation_shortest_arc_and_no_residual_velocity() -> void:
	var config: C_Grabbable = C_Grabbable.new()
	assert_eq(
		GrabPhysicsSolver.rotation_velocity(Quaternion.IDENTITY, -Quaternion.IDENTITY, 1.0 / 60.0, GrabControlProfile.from_grabbable(config)),
		Vector3.ZERO,
	)
	var angular_velocity: Vector3 = GrabPhysicsSolver.rotation_velocity(
		Quaternion.IDENTITY,
		Quaternion.IDENTITY,
		1.0 / 60.0,
		GrabControlProfile.from_grabbable(config),
	)
	assert_eq(angular_velocity, Vector3.ZERO)

	var offset: Quaternion = Quaternion.IDENTITY
	for step_index: int in 1000:
		offset = GrabPhysicsSolver.rotated_offset(offset, Vector2(4.0, 3.0))
	assert_almost_eq(offset.length(), 1.0, 0.00001)


## Импульс броска переводит желаемое изменение скорости и массу в Н·с.
func test_throw_impulse_converts_scaled_velocity_change_to_mass_impulse() -> void:
	assert_eq(GrabPhysicsSolver.throw_impulse(Vector3.FORWARD, 10.0, 5.0), Vector3(0.0, 0.0, -50.0))
	assert_eq(GrabPhysicsSolver.throw_impulse(Vector3.FORWARD, 5.0, 75.0), Vector3(0.0, 0.0, -375.0))
	assert_eq(GrabPhysicsSolver.throw_impulse(Vector3.FORWARD, 0.0, 120.0), Vector3.ZERO)
#endregion


#region Реальное физическое исполнение
## Solver прикладывает силу; фактическое движение к опоре выполняет физический цикл.
func test_solver_moves_dynamic_box_to_anchor_without_teleporting() -> void:
	box_body.gravity_scale = 1.0
	var initial_position: Vector3 = box_body.global_position
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	assert_eq(box_body.global_position, initial_position)
	for physics_tick: int in 100:
		await get_tree().physics_frame
	assert_almost_eq(box_body.global_position.z, -1.25, 0.1)
	assert_almost_eq(box_body.global_position.y, 1.0, 0.1)
	assert_not_null(GrabService.held_relationship(box_entity))


## Большой разрыв между телом и опорой освобождает хват и массу груза.
func test_teleport_breaks_grip_and_restores_carry_state() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	holder_body.position.x = 20.0
	for physics_tick: int in 3:
		await get_tree().physics_frame
	assert_null(GrabService.held_relationship(box_entity))
	assert_false(carry_load.active)


## Физическая стена скрывает цель от наведения и блокирует захват.
func test_wall_occludes_targeting_and_pickup() -> void:
	var wall: StaticBody3D = make_wall(Vector3(0.0, 1.0, -0.75))
	for physics_tick: int in 2:
		await get_tree().physics_frame
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	assert_null(InteractionTargetingGeometry.find_target(holder_entity, interactor))
	assert_false(GrabService.try_pickup(holder_entity, box_entity))
	wall.free()


## Удерживаемая коробка сталкивается со стеной, сохраняя хват без телепорта.
func test_held_box_collides_with_wall_instead_of_snapping_through() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	var wall: StaticBody3D = make_wall(Vector3(0.0, 1.0, -2.5))
	var grip: R_HeldBy = GrabService.held_relationship(box_entity).relation as R_HeldBy
	grip.hold_distance = 3.3
	for physics_tick: int in 100:
		await get_tree().physics_frame
	assert_gt(box_body.global_position.z, -2.3)
	assert_not_null(GrabService.held_relationship(box_entity))
	wall.free()


## Создаёт физическую стену для проверок перекрытия луча и движения.
func make_wall(location: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = location
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5.0, 5.0, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	grab_world.add_child(wall)
	return wall
#endregion


#region Приоритет ввода и аварийное освобождение
## Один фронт ввода исполняется один раз за физический такт.
func test_player_input_edges_are_consumed_once_on_physics_tick() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var input_system: CapturedInput = CapturedInput.new()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	input_system.feed_event(event)
	var holders: Array[Entity] = [holder_entity]
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_true(input_state.interact_pressed)
	InteractionInputFixture.advance(holder_entity)
	assert_eq(GrabService.held_object(holder_entity), box_entity)
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_false(input_state.interact_pressed)
	InteractionInputFixture.advance(holder_entity)
	assert_eq(GrabService.held_object(holder_entity), box_entity)
	input_system.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Захват поворота не накапливает движение мыши для позднего скачка камеры.
func test_rotation_priority_does_not_accumulate_camera_input() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	var input_system: CapturedInput = CapturedInput.new()
	var holders: Array[Entity] = [holder_entity]
	Input.action_press(&"action_secondary")
	input_system.feed_event(_mouse_motion(Vector2(40.0, 20.0)))
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	InteractionInputFixture.advance(holder_entity)
	assert_true(grab_control.rotation_active)
	assert_eq(input_state.direction_look, Vector3.FORWARD)
	assert_eq(input_state.look_delta, Vector2(40.0, 20.0))
	Input.action_release(&"action_secondary")
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	InteractionInputFixture.advance(holder_entity)
	assert_false(grab_control.rotation_active)
	assert_eq(input_state.direction_look, Vector3.FORWARD)
	input_system.feed_event(_mouse_motion(Vector2(10.0, 0.0)))
	input_system.process(holders, [[input_state]], 1.0 / 60.0)
	_apply_player_intent()
	assert_ne(input_state.direction_look, Vector3.FORWARD)
	input_system.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Внешний freeze снимает хват ближайшей обработкой управления.
func test_freezing_held_body_releases_on_next_control_tick() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	box_body.freeze = true
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_false(carry_load.active)
	assert_false(grab_control.rotation_active)


## Смерть участника освобождает предмет без нового ввода.
func test_death_releases_hold_without_requiring_input() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	var health: C_Health = C_Health.new()
	holder_entity.add_component(health)
	health.current = 0.0
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_false(carry_load.active)


## Solver поворачивает тело через физическую угловую скорость и останавливается у цели.
func test_solver_rotates_body_through_physics_velocity() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	var grip: R_HeldBy = GrabService.held_relationship(box_entity).relation as R_HeldBy
	grip.rotation_offset = Quaternion(Vector3.UP, PI * 0.5)
	for physics_tick: int in 6:
		await get_tree().physics_frame
	var result_rotation: Quaternion = box_body.global_basis.get_rotation_quaternion()
	assert_lt(result_rotation.angle_to(grip.rotation_offset), 0.15)
	assert_lt(box_body.angular_velocity.length(), 0.05)
	assert_not_null(GrabService.held_relationship(box_entity))
#endregion


#region Внешние изменения владения
## Второй внешний владелец отклоняется без повреждения первоначального хвата.
func test_external_second_holder_is_rejected_without_changing_original_grip() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	var other_holder: Entity = make_holder(Vector3(1.0, 0.0, 0.0))
	box_entity.add_relationship(Relationship.new(R_HeldBy.new(), other_holder))
	assert_eq(box_entity.relationships.size(), 1)
	assert_eq(GrabService.held_object(holder_entity), box_entity)
	assert_null(GrabService.held_object(other_holder))
	assert_false(box_body.can_sleep)
	assert_true(box_body.get_collision_exceptions().has(holder_body))


## Удаление дублирующей пары связей не оставляет массу, исключения или запрет сна.
func test_external_duplicate_relation_cannot_leave_lifecycle_effects() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	box_entity.add_relationship(Relationship.new(R_HeldBy.new(), holder_entity))
	assert_lte(box_entity.relationships.size(), 1)
	# GECS удаляет совпадающие пары: отклонение точного дубликата освобождает обе связи.
	if GrabService.held_relationship(box_entity) == null:
		assert_false(carry_load.active)
		assert_false(box_body.get_collision_exceptions().has(holder_body))
		assert_true(box_body.can_sleep)


## Удаление владельца из World очищает исходящую связь предмета.
func test_world_removal_of_holder_releases_source_relationship() -> void:
	assert_true(GrabService.try_pickup(holder_entity, box_entity))
	grab_world.remove_entity(holder_entity)
	assert_null(GrabService.held_relationship(box_entity))
	assert_true(box_body.get_collision_exceptions().is_empty())
#endregion


#region Перенос RigidBody без игрового скрипта
## Тело без скрипта доступно физическому наведению без преждевременного создания игровой Entity.
func test_scriptless_rigid_body_is_a_physics_target_without_becoming_gameplay_target() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	assert_null(rock.get_script())
	assert_null(InteractionTargetingGeometry.find_target(holder_entity, interactor))
	assert_eq(InteractionTargetingGeometry.find_physics_target(holder_entity, interactor), rock)
	assert_null(PhysicsGrabTarget.handle_for(rock, false))


## Захват тела без скрипта создаёт runtime proxy и общие эффекты переноса.
func test_interact_picks_up_scriptless_rigid_body_through_runtime_proxy() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5), 12.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	interactor.target = null
	interactor.physics_target = rock
	input_state.interact_pressed = true
	input_state.input_tick += 1

	InteractionInputFixture.advance(holder_entity)

	var held: Entity = GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY)
	assert_not_null(held)
	assert_true(PhysicsGrabTarget.is_proxy(held))
	assert_eq(PhysicsGrabTarget.body_for(held), rock)
	assert_true(carry_load.active)
	assert_true(rock.get_collision_exceptions().has(holder_body))
	assert_eq((GrabService.held_relationship(held).relation as R_HeldBy).profile.allowed_hand_slots, 0)


## Слишком тяжёлое тело остаётся подсвеченным с объяснением отказа и без proxy.
func test_overweight_scriptless_body_stays_highlighted_and_shows_weight_message() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5), 121.0)
	var mesh: MeshInstance3D = rock.get_node("MeshInstance3D") as MeshInstance3D
	var previous_overlay: StandardMaterial3D = StandardMaterial3D.new()
	mesh.material_overlay = previous_overlay
	await get_tree().physics_frame
	await get_tree().physics_frame

	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	var targeting_system: S_InteractionTargeting = S_InteractionTargeting.new()
	var highlight_system: S_InteractionHighlight = S_InteractionHighlight.new()
	targeting_system.process([holder_entity], [[interactor]], 0.0)
	highlight_system.process([holder_entity], [[interactor]], 0.0)

	assert_eq(interactor.physics_target, rock)
	assert_not_null(mesh.material_overlay)
	assert_ne(mesh.material_overlay, previous_overlay)
	assert_null(
		InteractionActionResolver.resolve(
			holder_entity,
			DEF_InteractionAction.Slot.INTERACT,
		)
	)

	InteractionActionResolver.refresh_prompt(holder_entity)
	assert_eq(interactor.prompt_text, "Слишком Тяжелое")

	input_state.interact_pressed = true
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY))
	assert_null(PhysicsGrabTarget.handle_for(rock, false))

	rock.mass = 5.0
	targeting_system.process([holder_entity], [[interactor]], 0.0)
	highlight_system.process([holder_entity], [[interactor]], 0.0)
	InteractionActionResolver.refresh_prompt(holder_entity)
	assert_true(interactor.prompt_text.contains("[input=interact]"))
	assert_true(interactor.prompt_text.contains("Взять"))

	highlight_system.free()
	targeting_system.free()


## Общий захват тела соблюдает предел массы и явно отключённую возможность переноса.
func test_scriptless_rigid_body_respects_mass_and_no_carry_policy() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var strength: C_Strength = holder_entity.get_component(C_Strength) as C_Strength
	assert_eq(CarryLoadPolicy.maximum_mass_kg(strength), 120.0)
	var heavy: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5), 121.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(
		GrabService.can_pickup_body(
			holder_entity,
			heavy,
			C_Grabbable.HoldSlot.CARRY,
		)
	)
	assert_null(PhysicsGrabTarget.handle_for(heavy, false))

	heavy.mass = 5.0
	heavy.add_to_group(GrabService.NO_CARRY_GROUP)
	assert_false(
		GrabService.can_pickup_body(
			holder_entity,
			heavy,
			C_Grabbable.HoldSlot.CARRY,
		)
	)
	assert_null(PhysicsGrabTarget.handle_for(heavy, false))


## Отпускание proxy сохраняет инерцию исходного тела и восстанавливает столкновения.
func test_scriptless_release_preserves_inertia_and_restores_collision() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup_body(holder_entity, rock))
	var held: Entity = GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY)
	rock.linear_velocity = Vector3(2.0, 3.0, 4.0)
	rock.angular_velocity = Vector3(0.0, 2.0, 1.0)

	GrabService.release(holder_entity, held)

	assert_eq(rock.linear_velocity, Vector3(2.0, 3.0, 4.0))
	assert_eq(rock.angular_velocity, Vector3(0.0, 2.0, 1.0))
	assert_false(rock.get_collision_exceptions().has(holder_body))
	assert_false(carry_load.active)


## Общий solver двигает тело без игрового скрипта через силу, не присваивая transform.
func test_scriptless_solver_moves_body_without_assigning_transform() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup_body(holder_entity, rock))
	var held: Entity = GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY)
	var relation: Relationship = GrabService.held_relationship(held)
	var grip: R_HeldBy = relation.relation as R_HeldBy
	var anchor: Node3D = GrabService.object_anchor(holder_entity, held)
	var initial_position: Vector3 = rock.global_position

	assert_true(
		GrabPhysicsSolver.integrate_body(
			rock,
			1.0 / 60.0,
			anchor,
			grip,
			grip.profile,
			grip.profile.break_distance,
		)
	)
	assert_eq(rock.global_position, initial_position, "Solver must apply force, not teleport")

	for physics_tick: int in 10:
		await get_tree().physics_frame
		assert_true(
			GrabPhysicsSolver.integrate_body(
				rock,
				1.0 / 60.0,
				anchor,
				grip,
				grip.profile,
				grip.profile.break_distance,
			)
		)
	assert_gt(rock.global_position.z, initial_position.z)


## The real scheduled generic owner applies forces without assigning physical transform.
func test_generic_hold_world_owner_moves_scriptless_body_without_teleport() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup_body(holder_entity, rock))
	var owner: S_Grab = S_Grab.new()
	owner.group = "generic_hold_fixture"
	grab_world.add_system(owner)
	var initial_position: Vector3 = rock.global_position

	grab_world.process(1.0 / 60.0, owner.group)
	assert_eq(rock.global_position, initial_position, "Scheduled forces cannot teleport the body")
	for physics_tick: int in 10:
		await get_tree().physics_frame
		grab_world.process(1.0 / 60.0, owner.group)
	assert_gt(rock.global_position.z, initial_position.z)
	assert_not_null(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY))
	grab_world.remove_system(owner)


## Deferred invalid-grip retirement cannot clear a newly acquired binding of the same object.
func test_generic_hold_manual_flush_preserves_replacement_grip() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup_body(holder_entity, rock))
	var held: Entity = GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY)
	var previous: Relationship = GrabService.held_relationship(held)
	var owner: S_Grab = S_Grab.new()
	owner.group = "generic_hold_fixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	grab_world.add_system(owner)
	rock.freeze = true
	grab_world.process(1.0 / 60.0, owner.group)

	GrabService.release(holder_entity, held, false)
	rock.freeze = false
	assert_true(GrabService.try_pickup_body(holder_entity, rock))
	var replacement: Relationship = GrabService.held_relationship(held)
	assert_ne(replacement, previous)
	grab_world.flush_command_buffers()
	assert_eq(GrabService.held_relationship(held), replacement)
	assert_true(carry_load.active)
	assert_true(rock.get_collision_exceptions().has(holder_body))
	grab_world.remove_system(owner)


## Удаление исходного тела убирает proxy и производное состояние владельца.
func test_scriptless_body_removal_cleans_runtime_proxy_and_holder() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup_body(holder_entity, rock))
	var proxy: Entity = GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.CARRY)
	assert_not_null(proxy)

	rock.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(grab_control.held_carry)
	assert_false(carry_load.active)
	assert_false(is_instance_valid(proxy))


## Выход общего родителя не удаляет proxy, пока SceneTree обходит его детей.
func test_scriptless_proxy_cleanup_waits_until_parent_finishes_exiting() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var branch: Node3D = Node3D.new()
	grab_world.add_child(branch)
	var rock: RigidBody3D = make_raw_rigid_body(Vector3(0.0, 1.0, -1.5))
	var proxy: Entity = PhysicsGrabTarget.handle_for(rock, true)
	rock.reparent(branch)
	proxy.reparent(branch)
	assert_true(GrabService.try_pickup_body(holder_entity, rock))
	var proxy_id: String = proxy.id

	grab_world.remove_child(branch)
	assert_true(is_instance_valid(proxy), "Proxy cleanup waits until tree exit has completed")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(proxy))
	assert_false(grab_world.entity_id_registry.has(proxy_id))
	assert_null(grab_control.held_carry)
	assert_false(carry_load.active)
	branch.free()


## Отложенная очистка принадлежит исходному World, даже после смены ECS.world.
func test_scriptless_proxy_cleanup_keeps_its_original_world() -> void:
	var rock: RigidBody3D = make_raw_rigid_body(Vector3.ZERO)
	var proxy: Entity = PhysicsGrabTarget.handle_for(rock, true)
	var proxy_id: String = proxy.id
	var next_world: World = World.new()
	add_child(next_world)

	grab_world.remove_child(rock)
	ECS.world = next_world
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(proxy))
	assert_false(grab_world.entity_id_registry.has(proxy_id))
	assert_true(next_world.entities.is_empty())
	ECS.world = grab_world
	next_world.free()
	rock.free()


## Уже удалённый через World proxy не удаляется повторно при исчезновении тела.
func test_scriptless_body_exit_accepts_an_already_removed_proxy() -> void:
	var rock: RigidBody3D = make_raw_rigid_body(Vector3.ZERO)
	var proxy: Entity = PhysicsGrabTarget.handle_for(rock, true)
	grab_world.remove_entity(proxy)
	await get_tree().process_frame
	await get_tree().process_frame

	rock.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(proxy))
	assert_false(is_instance_valid(rock))
#endregion


#region Совместимость взаимодействия с тележкой
## CharacterBody тележки сохраняет своё действие после переноса обычного RigidBody.
func test_character_body_transport_remains_interactable_after_generic_rigidbody_carry() -> void:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var scene: PackedScene = load("res://content/entities/props/push_cart.tscn") as PackedScene
	var cart: Entity = scene.instantiate() as Entity
	var cart_body: CharacterBody3D = cart as Node as CharacterBody3D
	cart_body.position = Vector3(0.0, 0.7, -1.8)
	cart_body.set_physics_process(false)
	grab_world.add_entity(cart)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var interactor: C_Interactor = holder_entity.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingGeometry.find_target(holder_entity, interactor)
	interactor.physics_target = InteractionTargetingGeometry.find_physics_target(holder_entity, interactor)

	assert_eq(interactor.target, cart)
	assert_null(interactor.physics_target)
	assert_true(GrabService.within_pickup_reach(holder_entity, cart))
	assert_true(CartTransportService.can_begin(holder_entity, cart))

	var choice: InteractionActionChoice = InteractionActionResolver.resolve(
		holder_entity,
		DEF_InteractionAction.Slot.INTERACT,
	)
	assert_not_null(choice)
	if choice :
		assert_true(choice.action is DEF_CartTransportAction)

	input_state.interact_pressed = true
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_eq(CartTransportService.current(holder_entity), cart)
	CartTransportService.end(cart)
#endregion


#region Deferred cargo sampling
## Replacing the load aggregate discards a queued native-space sample before mutation.
func test_cart_cargo_manual_flush_rejects_replaced_component() -> void:
	var scene: PackedScene = load("res://content/entities/props/push_cart.tscn") as PackedScene
	var cart: E_TransportCart = scene.instantiate() as E_TransportCart
	cart.set_physics_process(false)
	grab_world.add_entity(cart)
	var original: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	var owner: S_CartCargo = S_CartCargo.new()
	owner.group = "cargo_fixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	grab_world.add_system(owner)
	grab_world.process(1.0 / 60.0, owner.group)

	cart.remove_component(C_CartTransport)
	var replacement: C_CartTransport = C_CartTransport.new()
	cart.add_component(replacement)
	grab_world.flush_command_buffers()
	assert_eq(original.cargo_update_frame, -1)
	assert_eq(replacement.cargo_update_frame, -1)
	assert_true(replacement.cargo.is_empty())
	grab_world.remove_system(owner)


## A native-space sample expires across physics frames instead of charging an old settling delta.
func test_cart_cargo_manual_flush_rejects_previous_physics_frame() -> void:
	var scene: PackedScene = load("res://content/entities/props/push_cart.tscn") as PackedScene
	var cart: E_TransportCart = scene.instantiate() as E_TransportCart
	cart.set_physics_process(false)
	grab_world.add_entity(cart)
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	var owner: S_CartCargo = S_CartCargo.new()
	owner.group = "cargo_fixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	grab_world.add_system(owner)
	grab_world.process(1.0 / 60.0, owner.group)
	await get_tree().physics_frame
	grab_world.flush_command_buffers()
	assert_eq(config.cargo_update_frame, -1)

	grab_world.process(1.0 / 60.0, owner.group)
	grab_world.flush_command_buffers()
	assert_eq(config.cargo_update_frame, Engine.get_physics_frames())
	grab_world.remove_system(owner)
#endregion


#region Физическое толкание и lifecycle
func _make_push_cart() -> Entity:
	box_body.position = Vector3(8.0, 1.0, -1.5)
	var scene: PackedScene = load("res://tests/fixtures/push_test_body.tscn") as PackedScene
	var cart: Entity = scene.instantiate() as Entity
	var body: RigidBody3D = cart as Node as RigidBody3D
	body.position = Vector3(0.0, 1.0, -1.8)
	body.gravity_scale = 0.0
	grab_world.add_entity(cart)
	return cart


## Толкание имеет отдельное владение и сохраняет инструменты в руках.
func test_push_contextual_start_stop_preserves_hands_and_uses_no_grab_slot() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	_grabbable(box_entity).allowed_hand_slots = 6
	_add_external_grip(box_entity, C_Grabbable.HoldSlot.RIGHT_HAND)
	var interactor: C_Interactor = holder_entity.get_component(C_Interactor)
	interactor.target = cart

	input_state.interact_pressed = true
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_eq(PushService.pushed_object(holder_entity), cart)
	assert_null(GrabService.held_relationship(cart))
	assert_false(cart.has_component(C_Grabbable))
	assert_eq(InteractionControlFocus.current(holder_entity), InteractionControlFocus.Priority.PUSH)

	input_state.interact_pressed = false
	input_state.action_main_pressed = true
	input_state.physical_override = true
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), box_entity)

	input_state.interact_pressed = true
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_null(PushService.pushed_object(holder_entity))
	assert_eq(GrabService.held_in_slot(holder_entity, C_Grabbable.HoldSlot.RIGHT_HAND), box_entity)
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.HANDS,
	)


## Старый физический режим толкания имеет авторские скорости и не запускает мотор заднего хода.
func test_push_fixed_forward_turn_speeds_and_no_reverse_motor() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	var body: RigidBody3D = cart as Node as RigidBody3D
	var config: C_Pushable = cart.get_component(C_Pushable)
	var initial: Transform3D = body.global_transform
	assert_true(PushService.try_begin(holder_entity, cart))
	assert_eq(body.global_transform, initial)

	input_state.move_axis = Vector2(0.0, -1.0)
	for physics_tick: int in 4:
		await get_tree().physics_frame
	assert_almost_eq(body.linear_velocity.length(), config.forward_speed, 0.08)
	assert_lt(body.global_position.z, initial.origin.z)

	input_state.move_axis = Vector2(1.0, 0.0)
	for physics_tick: int in 3:
		await get_tree().physics_frame
	assert_almost_eq(body.angular_velocity.y, -config.turn_speed, 0.02)

	input_state.move_axis = Vector2(0.0, 1.0)
	for physics_tick: int in 3:
		await get_tree().physics_frame
	assert_almost_eq(body.linear_velocity.length(), 0.0, 0.02)
	input_state.input_tick += 1
	InteractionInputFixture.advance(holder_entity)
	assert_null(PushService.relationship(cart))


## Стена блокирует толкаемое тело без разрыва живого управления и телепорта.
func test_push_wall_collision_blocks_cart_without_teleport() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	assert_true(PushService.try_begin(holder_entity, cart))
	var wall: StaticBody3D = make_wall(Vector3(0.0, 1.0, -2.7))
	input_state.move_axis = Vector2(0.0, -1.0)

	for physics_tick: int in 45:
		await get_tree().physics_frame
	assert_gt((cart as Node as Node3D).global_position.z, -2.3)
	assert_not_null(PushService.relationship(cart))
	wall.free()


## Владелец физически следует за движущейся и поворачивающейся рукоятью.
func test_push_actor_physically_follows_turning_handle() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	assert_true(PushService.try_begin(holder_entity, cart))
	holder_entity.add_component(C_Motion.new())
	holder_body.freeze = false
	holder_body.gravity_scale = 0.0
	input_state.move_axis = Vector2(0.0, -1.0)

	for physics_tick: int in 25:
		await get_tree().physics_frame
	assert_lt(holder_body.global_position.z, -0.2)
	assert_not_null(PushService.relationship(cart))
	assert_gt(
		(cart as Node as Node3D).global_position.distance_to(holder_body.global_position),
		1.0,
	)


## Потеря переднего наведения или отключение владельца очищает толкание и возвращает физические параметры.
func test_push_lost_front_focus_and_disabled_actor_clean_up() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	assert_true(PushService.try_begin(holder_entity, cart))
	input_state.direction_look = Vector3.BACK
	for physics_tick: int in 3:
		await get_tree().physics_frame
	assert_null(PushService.relationship(cart))
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.HANDS,
	)

	input_state.direction_look = Vector3.FORWARD
	assert_true(PushService.try_begin(holder_entity, cart))
	grab_world.disable_entity(holder_entity)
	assert_null(PushService.relationship(cart))
	assert_true((cart as Node as RigidBody3D).can_sleep)


## Модальное окно приостанавливает мотор, сохраняя толкание до явного освобождения.
func test_push_modal_overlap_pauses_motor_and_retains_capture_after_ui_release() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	assert_true(PushService.try_begin(holder_entity, cart))
	var modal: RefCounted = RefCounted.new()
	var token: int = InteractionControlFocus.acquire(
		holder_entity,
		modal,
		InteractionControlFocus.Priority.MODAL,
	)
	input_state.move_axis = Vector2(1.0, -1.0)
	for physics_tick: int in 3:
		await get_tree().physics_frame
	assert_eq((cart as Node as RigidBody3D).linear_velocity, Vector3.ZERO)
	assert_eq((cart as Node as RigidBody3D).angular_velocity, Vector3.ZERO)

	InteractionControlFocus.release(holder_entity, token)
	assert_eq(InteractionControlFocus.current(holder_entity), InteractionControlFocus.Priority.PUSH)
	assert_eq(PushService.pushed_object(holder_entity), cart)
	grab_world.remove_entity(cart)
	assert_null(PushService.pushed_object(holder_entity))
	assert_eq(
		InteractionControlFocus.current(holder_entity),
		InteractionControlFocus.Priority.HANDS,
	)
	cart.free()


## A queued push check cannot retire a replacement session even if the pair loses focus.
func test_push_manual_flush_preserves_replacement_binding() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	assert_true(PushService.try_begin(holder_entity, cart))
	var previous: Relationship = PushService.relationship(cart)
	var owner: S_Push = S_Push.new()
	owner.group = "push_fixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	grab_world.add_system(owner)
	grab_world.process(1.0 / 60.0, owner.group)

	PushService.end(holder_entity, cart)
	assert_true(PushService.try_begin(holder_entity, cart))
	var replacement: Relationship = PushService.relationship(cart)
	assert_ne(replacement, previous)
	input_state.direction_look = Vector3.BACK
	grab_world.flush_command_buffers()
	assert_eq(PushService.relationship(cart), replacement)

	grab_world.process(1.0 / 60.0, owner.group)
	grab_world.flush_command_buffers()
	assert_null(PushService.relationship(cart), "A current scheduled check retires the invalid session")
	grab_world.remove_system(owner)


## Занятое тело и перекрытая стеной рукоять не допускают второго владельца.
func test_push_rejects_occupied_cart_and_wall_occluded_start() -> void:
	var cart: Entity = _make_push_cart()
	await get_tree().physics_frame
	assert_true(PushService.try_begin(holder_entity, cart))
	var other_actor: Entity = make_holder(Vector3(0.2, 0.0, 0.0))
	assert_false(PushService.try_begin(other_actor, cart))
	cart.add_relationship(Relationship.new(R_PushedBy.new(), other_actor))
	assert_eq(PushService.pushed_object(holder_entity), cart)
	assert_null(PushService.pushed_object(other_actor))
	PushService.end(holder_entity, cart)

	var wall: StaticBody3D = make_wall(Vector3(0.0, 1.0, -0.8))
	await get_tree().physics_frame
	assert_false(PushService.try_begin(holder_entity, cart))
	wall.free()
#endregion
