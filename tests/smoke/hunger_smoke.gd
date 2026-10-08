extends Node
## Исторический сквозной сценарий голода: еда, масса груза, проекция клиента и боевой исход.

const FRAME_DELTA: float = 1.0 / 60.0
const UI_FRAMES: int = 32
const HEAVY_MASS_KG: float = 40.0
const PREDATORY_MARGIN: float = 1.0


#region Connected headless scenario
func _ready() -> void:
	_run.call_deferred()


## Uses current authored hunger policy, a real carried body and an explicit legacy customer visit.
func _run() -> void:
	var level: Node = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	level.set("autosave_path", "")
	add_child(level)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	var actor_body: Node3D = actor as Node as Node3D
	actor_body.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = null

	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	assert(hunger != null and hunger.policy != null)
	hunger.value = 0.0
	var active_before: float = hunger.active_seconds
	ECS.world.process(1.0, "GamePlay")
	assert(is_equal_approx(hunger.value, hunger.policy.growth_per_second))
	assert(is_equal_approx(hunger.active_seconds, active_before + 1.0))
	assert(HungerService.set_value(actor, hunger.policy.hungry_threshold))
	assert(HungerRules.tier(hunger) == C_Hunger.Tier.HUNGRY)
	var food: DEF_FoodEffect = load("res://content/definitions/gameplay/hunger/def_food_bread.tres") as DEF_FoodEffect
	assert(HungerService.apply_food(actor, food))
	assert(hunger.value == maxf(0.0, hunger.policy.hungry_threshold - food.hunger_relief))

	# The real carry body is independent of the current district supply assortment.
	var heavy: Entity = (load("res://content/domains/interaction/entities/box.tscn") as PackedScene).instantiate() as Entity
	var heavy_body: RigidBody3D = heavy as Node as RigidBody3D
	heavy_body.mass = HEAVY_MASS_KG
	heavy_body.gravity_scale = 0.0
	level.add_child(heavy_body)
	ECS.world.add_entity(heavy, null, false)
	heavy_body.global_position = actor_body.global_position + Vector3(0, 0.8, -1.5)

	var ray: RayCast3D = GrabQueries.interaction_raycast(actor)
	ray.look_at((heavy as Node as Node3D).global_position + Vector3.UP * 0.2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(GrabService.try_pickup(actor, heavy, C_Grabbable.HoldSlot.CARRY))
	var carry: C_CarryLoad = actor.get_component(C_CarryLoad) as C_CarryLoad
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
	var baseline: float = motion.max_speed
	var carried_speed: float = MotionRules.effective_speed(motion, carry, strength)
	hunger.value = 75.0
	assert(is_equal_approx(MotionRules.effective_speed(motion, carry, strength, hunger), carried_speed * hunger.policy.starving_speed_multiplier))
	assert(HungerService.apply_food(actor, food))
	assert(HungerService.apply_food(actor, food))
	assert(HungerRules.tier(hunger) == C_Hunger.Tier.NORMAL)
	assert(is_equal_approx(MotionRules.effective_speed(motion, carry, strength, hunger), carried_speed) and motion.max_speed == baseline)
	GrabReleaseService.release(actor, heavy)
	ECS.world.remove_entity(heavy)

	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"smoke/hunger"
	visit.customer_id = &"smoke/hunger/recipient"
	visit.package_id = "smoke/hunger/parcel"
	visit.definition = DEF_Customer.new()
	visit.started = true
	flow.visits = [visit]
	var customer: E_NpcCharacter = (load("res://content/domains/customers/entities/customer.tscn") as PackedScene).instantiate() as E_NpcCharacter
	var customer_body: RigidBody3D = customer as Node as RigidBody3D
	customer_body.freeze = true
	level.add_child(customer_body)
	ECS.world.add_entity(customer, null, false)
	var customer_rid: RID = customer_body.get_rid()
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = visit.visit_id
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var order: String = visit.package_id
	hunger.value = hunger.policy.maximum * hunger.policy.predatory_threshold + PREDATORY_MARGIN
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
		if debug.text.contains("Starving"):
			break

	assert(debug.text == HungerPresentation.debug_text(actor).get_slice("\n", 0))
	var full_debug: String = HungerPresentation.debug_text(actor)
	assert(full_debug.contains("Starving") and full_debug.contains("до следующего") and full_debug.contains("Задача:"))
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
#endregion
