extends Node

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 900
const UI_FRAMES: int = 32


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	add_child(level)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	var actor_body: RigidBody3D = actor as Node as RigidBody3D
	actor_body.freeze = true
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	assert(hunger != null and hunger.policy != null)
	hunger.value = 0.0
	ECS.world.process(200.0, "GamePlay")
	assert(HungerService.tier(hunger) == C_Hunger.Tier.HUNGRY and hunger.value == 40.0)
	var food: DEF_FoodEffect = load("res://content/definitions/gameplay/hunger/def_food_bread.tres") as DEF_FoodEffect
	assert(HungerService.apply_food(actor, food) and hunger.value == 5.0)
	var heavy: Entity = level.get_node("Entityes/Parcel_001_03") as Entity
	actor_body.global_position = (heavy as Node as Node3D).global_position + Vector3(0, 0.1, 1.8)
	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	ray.look_at((heavy as Node as Node3D).global_position + Vector3.UP * 0.2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(GrabService.try_pickup(actor, heavy, C_Grabbable.HoldSlot.CARRY))
	var carry: C_CarryLoad = actor.get_component(C_CarryLoad) as C_CarryLoad
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
	var baseline: float = motion.max_speed
	var carried_speed: float = CharacterMotionSolver.effective_speed(motion, carry, strength)
	hunger.value = 75.0
	assert(is_equal_approx(CharacterMotionSolver.effective_speed(motion, carry, strength, hunger), carried_speed * hunger.policy.starving_speed_multiplier))
	assert(HungerService.apply_food(actor, food))
	assert(HungerService.apply_food(actor, food))
	assert(HungerService.tier(hunger) == C_Hunger.Tier.NORMAL)
	assert(is_equal_approx(CharacterMotionSolver.effective_speed(motion, carry, strength, hunger), carried_speed) and motion.max_speed == baseline)
	GrabService.release(actor, heavy)
	assert(PackageRegistrationService.register_package(CustomerFlowService.parcel_for("base_supply:1:books")).outcome == PackageScanResult.Outcome.REGISTERED)
	var cycle: C_DayCycle = DayPhaseService.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	var customer: E_Customer = null
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		ECS.world.process(FRAME_DELTA, "Physics")
		await get_tree().physics_frame
		customer = CustomerFlowService.waiting_customer()
		if customer != null:
			break
	assert(customer != null)
	var customer_body: RigidBody3D = customer as Node as RigidBody3D
	var customer_rid: RID = customer_body.get_rid()
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	var order: String = visit.package_id
	hunger.value = 75.0
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if (customer.get_node("HungerPerception/Food") as Node3D).visible:
			break
	assert((customer.get_node("HungerPerception/Food") as Node3D).visible)
	assert(not (customer.get_node("Body") as Node3D).visible)
	assert(customer_body.get_rid() == customer_rid and visit.package_id == order)
	var context: CustomerDialogueContext = CustomerDialogueContext.new(actor, customer)
	assert(context.perceived_text("Заказ клиента") == "Съешь меня")
	var debug: Label = level.get_node("InteractionHud/Overlay/PlayerDebugPanel/Debug/HungerDebug") as Label
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if debug.text.contains("Starving") and debug.text.contains("Пороги"):
			break
	assert(debug.text.contains("Starving") and debug.text.contains("до следующего") and debug.text.contains("Задача:"))
	var weapon: Entity = level.get_node("Entityes/UtilityBlade") as Entity
	assert(CombatService.hit(actor, weapon, customer, 40.0))
	assert((customer.get_component(C_Health) as C_Health).current == 40.0)
	var full_food: DEF_FoodEffect = DEF_FoodEffect.new()
	full_food.hunger_relief = 100.0
	assert(HungerService.apply_food(actor, full_food))
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		if (customer.get_node("Body") as Node3D).visible:
			break
	assert((customer.get_node("Body") as Node3D).visible)
	assert(not (customer.get_node("HungerPerception/Food") as Node3D).visible)
	assert(context.perceived_text("Заказ клиента") == "Заказ клиента" and visit.package_id == order)
	assert(CombatService.hit(actor, weapon, customer, 40.0))
	assert(customer.has_component(C_Death))
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(visit.finished and visit.defeated_by_player)
	level.free()
	ECS.world = null
	print("Hunger active time food carry attack modifiers reversible NPC perception and debug HUD smoke PASS")
	get_tree().quit.call_deferred()
