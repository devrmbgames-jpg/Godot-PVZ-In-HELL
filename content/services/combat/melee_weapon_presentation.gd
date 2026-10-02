extends RefCounted
## AnimationPlayer animates only authored visual nodes; CombatService remains hit authority.
class_name MeleeWeaponPresentation

const RESET_ANIMATION: StringName = &"RESET"


static func start(weapon: Entity) -> void:
	var config: C_MeleeWeapon = weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon
	var player: AnimationPlayer = _player(weapon, config)
	if player == null or not player.has_animation(config.strike_animation):
		return
	# Drive pose from the same strike clock, including large ticks and cancellation.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(config.strike_animation)
	player.advance(0.0)


static func update(weapon: Entity, elapsed: float, attack: DEF_MeleeAttack) -> void:
	var config: C_MeleeWeapon = weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon
	var player: AnimationPlayer = _player(weapon, config)
	if player == null or attack == null or not player.has_animation(config.strike_animation):
		return
	var duration: float = attack.windup_seconds + attack.active_seconds + attack.recovery_seconds
	if duration <= 0.0:
		return
	var animation: Animation = player.get_animation(config.strike_animation)
	player.seek(clampf(elapsed / duration, 0.0, 1.0) * animation.length, true)


static func reset(weapon: Entity) -> void:
	if not is_instance_valid(weapon):
		return
	var config: C_MeleeWeapon = weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon
	var player: AnimationPlayer = _player(weapon, config)
	if player == null:
		return
	if player.is_inside_tree() and player.has_animation(RESET_ANIMATION):
		player.play(RESET_ANIMATION)
		player.advance(0.0)
	player.stop()


## Anchoring uses the same swing as visual feedback; it never schedules a combat hit.
static func play_tool_action(weapon: Entity) -> void:
	var config: C_MeleeWeapon = weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon
	var player: AnimationPlayer = _player(weapon, config)
	if player == null or not player.has_animation(config.strike_animation):
		return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	player.play(config.strike_animation)


static func _player(weapon: Entity, config: C_MeleeWeapon) -> AnimationPlayer:
	if config == null or config.animation_player_path.is_empty():
		return null
	return weapon.get_node_or_null(config.animation_player_path) as AnimationPlayer
