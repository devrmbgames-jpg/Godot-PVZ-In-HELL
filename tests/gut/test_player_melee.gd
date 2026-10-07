extends GutTest
## Проверяет окно удара игрока, владение оружием и приоритет инструмента без подмены физики анимацией.

var _world: World = null
var _player: Entity = null
var _target: Entity = null
var _weapon: Entity = null

## Replaces a live strike synchronously from its committed damage fact.
class StrikeReplacer extends Observer:
	var _actor: Entity
	var _weapon: Entity
	var _replaced: bool = false

	#region Damage reaction fixture
	## Sets required fixture endpoints before registering the consumer.
	func configure(actor: Entity, weapon: Entity) -> void:
		_actor = actor
		_weapon = weapon


	## Watches authoritative terminal health results.
	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	## Cancels/restarts once, before the preceding strike's receipt reaches its clock owner.
	func each(_event: Variant, _victim: Entity, payload: Variant = null) -> void:
		var result: DamageResult = payload as DamageResult
		if _replaced or result.request.instigator != _actor or result.applied_amount <= 0.0:
			return
		_replaced = true
		CombatService.cancel_strike(_actor)
		var restarted: bool = CombatService.start_strike(_actor, _weapon)
		assert(restarted)
	#endregion


#region Окружение и настоящее оружие
## Создаёт игрока, цель и реально удерживаемый нож с observers урона/хвата.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HealthLifecycle.new())
	_world.add_observer(O_GrabLifecycle.new())
	_player = _character(Vector3.ZERO)
	_player.add_component(C_Combat.new())
	_player.add_component(C_GrabControl.new())
	_player.add_component(C_Interactor.new())
	_player.add_component(C_Controller.new())
	_player.add_component(C_CarryLoad.new())

	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0.5, 1.0, 0.0)
	(_player as Node).add_child(anchor)
	(_player as E_RigidBodyCharacter).right_hand_slot = anchor
	_target = _character(Vector3(0, 0, -1.3))
	_weapon = (load("res://content/entities/tools/utility_blade.tscn") as PackedScene).instantiate() as Entity
	_world.add_entity(_weapon)
	(_weapon as Node as RigidBody3D).gravity_scale = 0.0
	(_weapon as Node as Node3D).global_position = anchor.global_position

	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	_weapon.add_relationship(Relationship.new(grip, _player))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var weapon_state: C_MeleeWeapon = _weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon
	assert_not_null(weapon_state)
	assert_not_null(weapon_state.attack)
	assert_not_null(GrabService.held_relationship(_weapon))


## Удаляет World и очищает ссылки оружия и участников.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_player = null
	_target = null
	_weapon = null


func _character(position: Vector3) -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/entities/characters/e_rigid_body_character.gd"))
	var entity: E_RigidBodyCharacter = body as Node as E_RigidBodyCharacter
	var health: C_Health = C_Health.new()
	health.current = 100.0
	health.value = 100.0
	entity.component_resources = [health, C_Living.new()]

	var head: Marker3D = Marker3D.new()
	head.position.y = 1.5
	body.add_child(head)
	entity.head_axis_x = head
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	body.add_child(collision)
	_world.add_entity(entity)
	body.global_position = position
	return entity


#endregion

#region Queued and synchronous replacement
## A queued old clock cannot advance a restarted strike using the same authored Definition.
func test_manual_clock_rejects_cancelled_and_restarted_strike() -> void:
	assert_true(CombatService.start_strike(_player, _weapon))
	var owner: S_PlayerMelee = S_PlayerMelee.new()
	owner.group = "queued_melee"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.5, owner.group)
	CombatService.cancel_strike(_player)
	assert_true(CombatService.start_strike(_player, _weapon))
	_world.flush_command_buffers()
	var state: C_Combat = _player.get_component(C_Combat) as C_Combat
	assert_eq(state.elapsed, 0.0)
	assert_eq(state.phase, C_Combat.Phase.WINDUP)
	assert_eq((_target.get_component(C_Health) as C_Health).current, 100.0)
	owner.command_buffer_flush_mode = System.FlushMode.PER_SYSTEM
	_world.process(state.strike.windup_seconds, owner.group)
	assert_true(state.hit_committed)
	assert_lt((_target.get_component(C_Health) as C_Health).current, 100.0)


## The old hit receipt cannot mark or finish a strike started during damage publication.
func test_damage_fact_replacement_keeps_new_strike_uncommitted() -> void:
	var consumer: StrikeReplacer = StrikeReplacer.new()
	consumer.configure(_player, _weapon)
	_world.add_observer(consumer)
	assert_true(CombatService.start_strike(_player, _weapon))
	var state: C_Combat = _player.get_component(C_Combat) as C_Combat
	var windup: float = state.strike.windup_seconds
	CombatFixture.melee(_player, windup)
	assert_eq(state.elapsed, 0.0)
	assert_eq(state.phase, C_Combat.Phase.WINDUP)
	assert_false(state.hit_committed)
	var health_after_first: float = (_target.get_component(C_Health) as C_Health).current
	assert_lt(health_after_first, 100.0)
	CombatFixture.melee(_player, windup)
	assert_true(state.hit_committed)
	assert_lt((_target.get_component(C_Health) as C_Health).current, health_after_first)
#endregion

#region Окно, ввод и анимация удара
## Окно атаки наносит один удар и требует восстановления до новой атаки.
func test_player_window_has_one_hit_and_recovery_then_can_defeat_target() -> void:
	var health: C_Health = _target.get_component(C_Health) as C_Health
	assert_true(CombatService.start_strike(_player, _weapon))
	CombatFixture.melee(_player, 0.15)
	assert_eq(health.current, 100.0)
	CombatFixture.melee(_player, 0.1)
	assert_eq(health.current, 60.0)
	CombatFixture.melee(_player, 0.1)
	assert_eq(health.current, 60.0)
	assert_false(CombatService.start_strike(_player, _weapon))
	CombatFixture.melee(_player, 1.0)
	for hit_index: int in 2:
		assert_true(CombatService.start_strike(_player, _weapon))
		CombatFixture.melee(_player, 1.0)
	assert_eq(health.current, 0.0)
	assert_true(_target.has_component(C_Death))


## Один фронт выбирает бросок либо удар, сохраняя исходный снимок ввода.
func test_one_primary_click_throws_or_attacks_and_keeps_raw_input() -> void:
	var controller: C_Controller = _player.get_component(C_Controller) as C_Controller
	controller.input_tick = 1
	controller.action_main_pressed = true
	controller.physical_override = true
	InteractionActionResolver.handle_input(_player)
	assert_null(GrabService.held_relationship(_weapon))
	assert_eq((_player.get_component(C_Combat) as C_Combat).phase, C_Combat.Phase.READY)
	assert_true(controller.action_main_pressed)
	assert_true(controller.physical_override)

	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	_weapon.add_relationship(Relationship.new(grip, _player))
	controller.input_tick += 1
	controller.physical_override = false
	InteractionActionResolver.handle_input(_player)
	assert_not_null(GrabService.held_relationship(_weapon))
	assert_eq((_player.get_component(C_Combat) as C_Combat).phase, C_Combat.Phase.WINDUP)
	assert_true(controller.action_main_pressed)


## Отпускание оружия отменяет ожидающий удар.
func test_dropped_weapon_cancels_pending_hit() -> void:
	assert_true(CombatService.start_strike(_player, _weapon))
	GrabService.release(_player, _weapon)
	CombatFixture.melee(_player, 0.3)
	assert_eq((_target.get_component(C_Health) as C_Health).current, 100.0)
	assert_eq((_player.get_component(C_Combat) as C_Combat).phase, C_Combat.Phase.READY)


## Анимация ножа следует часам удара, не двигает физическое тело и сбрасывается при отпускании.
func test_knife_animation_stabs_forward_on_strike_clock_and_resets_on_drop() -> void:
	var blade: Node3D = _weapon.get_node("Blade") as Node3D
	var baseline: Vector3 = blade.position
	var body: Node3D = _weapon as Node as Node3D
	var physical_pose: Transform3D = body.global_transform
	var animation: AnimationPlayer = _weapon.get_node("AttackAnimation") as AnimationPlayer
	assert_true(CombatService.start_strike(_player, _weapon))
	CombatFixture.melee(_player, 0.2)
	assert_lt(blade.position.z, -0.5, "AnimationPlayer produces a forward stab at the hit window")
	assert_eq((_target.get_component(C_Health) as C_Health).current, 60.0)
	assert_eq(body.global_transform, physical_pose, "Animation leaves native rigid transform alone")
	CombatFixture.melee(_player, 0.1)
	assert_eq((_target.get_component(C_Health) as C_Health).current, 60.0, "Pose updates do not duplicate damage")
	GrabService.release(_player, _weapon)
	CombatFixture.melee(_player, 0.1)
	assert_false(animation.is_playing())
	assert_eq(blade.position, baseline, "Cancellation restores authored mesh pose")


## Молоток атакует NPC, сохраняя более высокий приоритет доступного крепления.
func test_hammer_can_attack_with_overhead_swing_and_preserves_anchoring_action() -> void:
	GrabService.release(_player, _weapon)
	_weapon = (load("res://content/entities/tools/hammer.tscn") as PackedScene).instantiate() as Entity
	_world.add_entity(_weapon)
	(_weapon as Node as RigidBody3D).gravity_scale = 0.0
	(_weapon as Node as Node3D).global_position = (_player as E_PhysicalCharacter).right_hand_slot.global_position
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	_weapon.add_relationship(Relationship.new(grip, _player))
	assert_true(_weapon.has_component(C_AnchorTool))

	var actions: C_InteractionActionSet = _weapon.get_component(C_InteractionActionSet) as C_InteractionActionSet
	assert_true(actions.actions[0] is DEF_AnchorAction)
	assert_gt(actions.actions[0].priority, actions.actions[1].priority, "Valid fastening takes precedence")
	(_player.get_component(C_Interactor) as C_Interactor).target = _target
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(_player, DEF_InteractionAction.Slot.PRIMARY)
	assert_not_null(choice)
	if choice != null:
		assert_true(choice.action is DEF_MeleeAction, "NPC target uses the strike action")

	var head: Node3D = _weapon.get_node("Head") as Node3D
	var baseline: Vector3 = head.position
	assert_true(CombatService.start_strike(_player, _weapon))
	CombatFixture.melee(_player, 0.12)
	assert_gt(head.position.y, baseline.y + 0.2, "Hammer raises overhead in windup")
	CombatFixture.melee(_player, 0.13)
	assert_lt(head.position.y, baseline.y, "Hammer swings downward into the active window")
	assert_eq((_target.get_component(C_Health) as C_Health).current, 75.0)
	CombatFixture.melee(_player, 1.0)
	assert_eq(head.position, baseline)


#endregion

#region Геометрия и защита урона
## C_NoDamage владельца блокирует урон удерживаемого оружия.
func test_actor_no_damage_guard_applies_to_held_weapon() -> void:
	_player.add_component(C_NoDamage.new())
	assert_true(CombatService.start_strike(_player, _weapon))
	CombatFixture.melee(_player, 1.0)
	assert_eq((_target.get_component(C_Health) as C_Health).current, 100.0)


## Большое число посторонних collider не вытесняет подходящую боевую цель.
func test_scenery_count_does_not_hide_melee_target() -> void:
	for index: int in 40:
		var obstacle: StaticBody3D = StaticBody3D.new()
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(0.05, 0.05, 0.05)
		collision.shape = shape
		obstacle.add_child(collision)
		_world.add_child(obstacle)
		obstacle.position = Vector3(1.0, 1.0, 0.1 + index * 0.01)
	await get_tree().physics_frame
	assert_true(CombatService.start_strike(_player, _weapon))
	CombatFixture.melee(_player, 1.0)
	assert_eq((_target.get_component(C_Health) as C_Health).current, 60.0)


## Общая защита контакта не наносит владельцу урон его собственным удерживаемым предметом.
func test_existing_r08_impact_guard_prevents_own_held_object_damage() -> void:
	var receiver: C_ImpactReceiver = C_ImpactReceiver.new()
	receiver.profile = load("res://content/definitions/gameplay/def_impact_living.tres") as DEF_ImpactProfile
	_player.add_component(receiver)
	_world.add_system(S_Impact.new())
	var contact: PhysicsContact = PhysicsContact.new()
	contact.body_a = _weapon as Node as PhysicsBody3D
	contact.body_b = _player as Node as PhysicsBody3D
	contact.normal_speed = 20.0
	contact.normal_impulse = 800.0
	contact.tick = Engine.get_physics_frames()
	(_weapon.get_component(C_ImpactInbox) as C_ImpactInbox).contacts.append(contact)
	_world.process(1.0 / 60.0)
	assert_eq((_player.get_component(C_Health) as C_Health).current, 100.0)
	assert_not_null(GrabService.held_relationship(_weapon))

#endregion
