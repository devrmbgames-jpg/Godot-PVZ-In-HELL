extends Node

const MAX_FRAMES: int = 600


func _ready() -> void:
	_run.call_deferred()


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
	var hp: float = health.current
	var hunger_value: float = hunger.value
	hud.set("player_status_enabled", false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not stats.visible)
	assert(is_equal_approx(health.current, hp) and is_equal_approx(hunger.value, hunger_value))
	level.free()
	print("PASS: player feedback: Health/Hunger/Money with debug disabled, physical four-face package tags/condition, presentation disable leaves gameplay unchanged")
	get_tree().quit()
