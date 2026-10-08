extends Node
## Исторический сценарий HUD, сканера, обратной связи урона и подсказки замка в основной сцене.

const MAX_FRAMES: int = 600


#region Исторический сценарий обратной связи
func _ready() -> void:
	_run.call_deferred()


## Проверяет производный HUD и предупреждения без изменения здоровья отключением UI.
func _run() -> void:
	var level: Node = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	level.set("autosave_path", "")
	add_child(level)
	level.set_physics_process(false)
	var player: Entity = level.get_node("Entityes/Player") as Entity
	(player as Node as RigidBody3D).freeze = true
	var hud: CanvasLayer = level.get_node("InteractionHud") as CanvasLayer
	hud.set("debug_status_enabled", false)
	hud.set("challenge_debug_enabled", false)
	for frame: int in MAX_FRAMES:
		ECS.world.process(1.0 / 60.0, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	assert(CustomerFlowService.parcel_for("base_supply:1:glass") != null)
	var health: C_Health = player.get_component(C_Health) as C_Health
	var hunger: C_Hunger = player.get_component(C_Hunger) as C_Hunger
	health.current = health.value * 0.5
	hunger.value = hunger.policy.starving_threshold
	WalletService.current().balance = -321
	WalletService.current().penalties = 60
	var parcel: Entity = CustomerFlowService.parcel_for("base_supply:1:glass")
	var condition: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	condition.damage = C_PackageState.Damage.DAMAGED
	condition.opening = C_PackageState.Opening.OPENED
	await get_tree().process_frame
	await get_tree().process_frame

	var stats: Control = hud.get_node("Overlay/PlayerStatusPanel") as Control
	assert(stats.visible)
	assert(not (hud.get_node("Overlay/PlayerDebugPanel") as Control).visible)
	assert(not (hud.get_node("Overlay/ChallengeDebugPanel") as Control).visible)
	assert(is_equal_approx((stats.get_node("Stats/HealthBar") as ProgressBar).value, health.current))
	assert(is_equal_approx((stats.get_node("Stats/HungerBar") as ProgressBar).value, hunger.value))
	assert((stats.get_node("Stats/Hunger") as Label).text.contains("Сильный голод"))
	assert((stats.get_node("Stats/Money") as Label).text.contains("-321"))

	var surface: MeshInstance3D = (parcel as E_Package).get_marking_surface()
	for index: int in 4:
		var label: Label3D = surface.get_node("PackageLabel%d" % index) as Label3D
		assert(label.visible and label.billboard == BaseMaterial3D.BILLBOARD_DISABLED)
		assert(label.text.contains("ХРУПКОЕ") and label.text.contains("Повреждена") and label.text.contains("Вскрыта"))
	for shipment: String in ["equipment", "oil"]:
		var other: Entity = CustomerFlowService.parcel_for("base_supply:1:" + shipment)
		var label: Label3D = (other as E_Package).get_marking_surface().get_node("PackageLabel0") as Label3D
		assert(label.text.contains("ТЯЖЁЛОЕ" if shipment == "equipment" else "ЖИДКОСТЬ"))
	await _check_damage(player, hud, parcel)
	await _check_locked_prompt(level, player)

	var scanner: E_Scanner = level.get_node("Entityes/Scanner") as E_Scanner
	var result: PackageScanResult = PackageRegistrationService.register_package(parcel)
	assert(result.outcome == PackageScanResult.Outcome.REGISTERED)
	scanner.scan_feedback.emit(result)
	var scan_text: Label3D = scanner.get_node("Feedback/Result") as Label3D
	assert(scan_text.text.contains("№%03d" % result.number))
	assert((scanner.get_node("Feedback/Beep") as AudioStreamPlayer3D).playing)
	result = PackageScanResult.new()
	scanner.scan_feedback.emit(result)
	assert(scan_text.text == result.message and not scan_text.text.contains("№000"))
	assert(not (scanner.get_node("Feedback/Beep") as AudioStreamPlayer3D).playing)

	var hp: float = health.current
	var hunger_value: float = hunger.value
	hud.set("player_status_enabled", false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not stats.visible)
	assert(is_equal_approx(health.current, hp) and is_equal_approx(hunger.value, hunger_value))
	level.free()
	print("PASS: player feedback: debug-disabled status/world tags, distinct damage/toxic/explosion results, bounded popup/sound/cleanup, real locked-door/key prompt, scanner confirmation/rejection, disabled UI leaves gameplay unchanged")
	get_tree().quit()


#endregion

#region Урон и доступ к двери
func _check_damage(player: Entity, hud: CanvasLayer, parcel: Entity) -> void:
	var view: DamageFeedbackView = hud.get_node("DamageFeedback") as DamageFeedbackView
	var warning: Label = view.get_node("Warning") as Label
	var player_hp: C_Health = player.get_component(C_Health) as C_Health
	for kind: DamageRequest.Type in [DamageRequest.Type.MELEE, DamageRequest.Type.TOXIC, DamageRequest.Type.EXPLOSION]:
		var before: float = player_hp.current
		var request: DamageRequest = DamageRequest.new()
		request.target = player
		request.damage_type = kind
		request.amount = 1.0
		assert(DamageRequestService.submit(request))
		await get_tree().process_frame
		await get_tree().process_frame
		assert(is_equal_approx(player_hp.current, before - 1.0))
		assert(warning.visible)
		assert(warning.text.contains("Ближняя атака" if kind == DamageRequest.Type.MELEE else "Токсичная зона" if kind == DamageRequest.Type.TOXIC else "Взрыв"))
		assert(not (view.get_node("Tint") as ColorRect).visible)
		assert((view.get_node("Sound") as AudioStreamPlayer).stream != null)

	var request: DamageRequest = DamageRequest.new()
	request.target = parcel
	request.amount = 1.0
	request.damage_type = DamageRequest.Type.IMPACT
	assert(DamageRequestService.submit(request))
	assert(not view.find_children("WorldDamageLabel*", "Label3D", false, false).is_empty())
	view.enabled = false
	await get_tree().process_frame
	await get_tree().process_frame

	var before: float = player_hp.current
	request.target = player
	assert(DamageRequestService.submit(request))
	assert(is_equal_approx(player_hp.current, before - 1.0))
	assert(not warning.visible)
	assert(view.find_children("WorldDamageLabel*", "Label3D", false, false).is_empty())


## Явно синхронизирует тестовую дверь и проверяет подсказку доступа по ключу.
func _check_locked_prompt(level: Node, player: Entity) -> void:
	var door: Entity = level.get_node("Entityes/DoorTemplate") as Entity
	var state: C_Openable = door.get_component(C_Openable) as C_Openable
	state.locked = true
	state.access = DEF_AccessRequirement.new()
	state.access.required_item_id = &"feedback_key"
	# Тестовое перемещение явно синхронизирует физическое полотно двери.
	(door as Node as AnimatableBody3D).sync_to_physics = false
	(door as Node as Node3D).global_transform = Transform3D(Basis.IDENTITY, Vector3(16, 0, 2))

	var leaf: RigidBody3D = door.get_node("RigidBody3D") as RigidBody3D
	leaf.freeze = true
	leaf.global_transform = (door as Node as Node3D).global_transform
	var point: Vector3 = (door as Node as Node3D).global_position + Vector3(0.8, 1.4, 0)
	await _aim(player, point)
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	assert(interactor.target == door, "door target=%s collider=%s point=%s leaf=%s" % [interactor.target, GrabService.interaction_raycast(player).get_collider(), point, leaf.global_position])
	InteractionActionResolver.refresh_prompt(player)
	assert(interactor.prompt_text.contains("Заперто") and not interactor.prompt_text.contains("Отпереть"))
	assert(state.locked)

	var hammer: Entity = level.get_node("Entityes/Hammer") as Entity
	var key: C_AccessItem = C_AccessItem.new()
	key.item_id = &"feedback_key"
	hammer.add_component(key)
	(hammer as Node as RigidBody3D).global_position = Vector3(17.5, 1.4, 3.5)
	await _aim(player, (hammer as Node as Node3D).global_position)
	assert(GrabService.try_pickup(player, hammer))
	await _aim(player, point)
	InteractionActionResolver.refresh_prompt(player)
	assert(interactor.target == door)
	assert(interactor.prompt_text.contains("Отпереть") and not interactor.prompt_text.contains("Заперто"))
	assert(not interactor.prompt_text.contains("Контекст"))
	assert(state.locked, "Presentation must not unlock the door")
	GrabService.release(player, hammer)


func _aim(player: Entity, point: Vector3) -> void:
	var ray: RayCast3D = GrabService.interaction_raycast(player)
	(player as Node as RigidBody3D).global_position = point + Vector3.BACK * 1.5
	ray.global_position = point + Vector3.BACK * 1.5
	ray.look_at(point, Vector3.UP)
	ray.target_position = Vector3(0, 0, -3)
	for frame: int in 2:
		await get_tree().physics_frame
	ray.force_raycast_update()

	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingGeometry.find_target(player, interactor)
	interactor.physics_target = InteractionTargetingGeometry.find_physics_target(player, interactor)

#endregion
