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
