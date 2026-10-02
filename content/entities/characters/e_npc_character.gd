@tool
extends E_RigidBodyCharacter
## Thin presentation hook driven by actual body velocity; animation never supplies root motion.
class_name E_NpcCharacter

const WALK_START_SPEED: float = 0.2
const WALK_STOP_SPEED: float = 0.1
const ANIMATION_BLEND_SECONDS: float = 0.15

@export var animation_player: AnimationPlayer = null
@export var navigation_agent: NavigationAgent3D = null
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"

var _walking: bool = false
var _navigation_dead: bool = false
var _avoidance_before_death: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint() and navigation_agent != null:
		navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)


func _on_navigation_velocity_computed(safe_velocity: Vector3) -> void:
	var intent: C_NpcIntent = get_component(C_NpcIntent) as C_NpcIntent
	if intent != null:
		intent.avoidance_velocity = Vector3(safe_velocity.x, 0.0, safe_velocity.z)
		intent.avoidance_frame = Engine.get_physics_frames()


## Engine participation only; reset restores the native agent's authored policy.
func sync_navigation_lifecycle(living: bool) -> void:
	if navigation_agent == null or living == (not _navigation_dead):
		return
	if living:
		navigation_agent.avoidance_enabled = _avoidance_before_death
	else:
		_avoidance_before_death = navigation_agent.avoidance_enabled
		navigation_agent.avoidance_enabled = false
	_navigation_dead = not living
	var intent: C_NpcIntent = get_component(C_NpcIntent) as C_NpcIntent
	if intent != null:
		intent.avoidance_velocity = Vector3.ZERO
		intent.avoidance_frame = -1


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or animation_player == null:
		return
	var combat: C_NpcCombat = get_component(C_NpcCombat) as C_NpcCombat
	if combat != null and combat.animation_driven and combat.phase != C_NpcCombat.Phase.READY:
		return
	var body: RigidBody3D = self as Node as RigidBody3D
	var speed: float = Vector2(body.linear_velocity.x, body.linear_velocity.z).length()
	_walking = speed > WALK_STOP_SPEED if _walking else speed >= WALK_START_SPEED
	var animation: StringName = walk_animation if _walking else idle_animation
	if animation_player.has_animation(animation) and animation_player.current_animation != animation:
		animation_player.play(animation, ANIMATION_BLEND_SECONDS)


## Method-track callbacks target this Entity, not the presentation AnimationPlayer.
func npc_attack_hit() -> void:
	if not Engine.is_editor_hint():
		NpcAttackService.commit_effect(self)


func npc_attack_finished() -> void:
	if not Engine.is_editor_hint():
		NpcAttackService.finish(self)
