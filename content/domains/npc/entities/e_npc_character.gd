@tool
extends E_RigidBodyCharacter
## Анимация по реальной скорости тела и участие в движке по жизни NPC; root motion не применяется.
class_name E_NpcCharacter

## Method-track requests an effect from the owner of the current attack.
signal attack_effect_requested
## Method-track requests completion from the owner of the current attack.
signal attack_finish_requested

const WALK_START_SPEED: float = 0.2
const WALK_STOP_SPEED: float = 0.1
const ANIMATION_BLEND_SECONDS: float = 0.15

## Авторский проигрыватель поз и method-track атак, без управления трансформом тела.
@export var animation_player: AnimationPlayer = null
## Авторский агент пути/avoidance; его callback поставляет кеш безопасной скорости.
@export var navigation_agent: NavigationAgent3D = null
## Имя авторской анимации покоя; обслуживание может выбрать другую позу.
@export var idle_animation: StringName = &"Idle"
## Имя анимации, выбираемой по фактической горизонтальной скорости.
@export var walk_animation: StringName = &"Walk"

var _walking: bool = false
var _navigation_dead: bool = false
var _avoidance_before_death: bool = false
var _death_presented: bool = false
var _living_layer: int = 0
var _living_mask: int = 0
var _living_freeze: bool = false
var _living_visible: bool = true


#region Подготовка и навигационное участие
func _ready() -> void:
	var body: RigidBody3D = self as Node as RigidBody3D
	_living_layer = body.collision_layer
	_living_mask = body.collision_mask
	_living_freeze = body.freeze
	_living_visible = body.visible
	if not Engine.is_editor_hint() and navigation_agent != null:
		navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)


func _on_navigation_velocity_computed(safe_velocity: Vector3) -> void:
	var intent: C_NpcIntent = get_component(C_NpcIntent) as C_NpcIntent
	if intent != null:
		intent.avoidance_velocity = Vector3(safe_velocity.x, 0.0, safe_velocity.z)
		intent.avoidance_frame = Engine.get_physics_frames()


## Отключает avoidance после смерти; явный сброс восстанавливает прежнюю политику агента и очищает кеш скорости.
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


#endregion

#region Анимация и терминальное состояние
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	sync_death_presentation()
	if _death_presented or animation_player == null:
		return

	var combat: C_NpcCombat = get_component(C_NpcCombat) as C_NpcCombat
	if combat != null and combat.animation_driven and combat.phase != C_NpcCombat.Phase.READY:
		return

	var body: RigidBody3D = self as Node as RigidBody3D
	var speed: float = Vector2(body.linear_velocity.x, body.linear_velocity.z).length()
	_walking = speed > WALK_STOP_SPEED if _walking else speed >= WALK_START_SPEED
	var animation: StringName = walk_animation if _walking else _stationary_animation()
	if animation_player.has_animation(animation) and animation_player.current_animation != animation:
		animation_player.play(animation, ANIMATION_BLEND_SECONDS)


## Позволяет сцене выбрать позу обслуживания на месте; реальное движение по-прежнему выбирает Walk.
func _stationary_animation() -> StringName:
	return idle_animation


## Скрывает и отключает тело/навигацию по терминальному состоянию, сохраняя Entity погибшего.
func sync_death_presentation() -> void:
	var health: C_Health = get_component(C_Health) as C_Health
	var dead: bool = has_component(C_Death) or (health != null and health.depleted)
	if dead == _death_presented:
		return

	_death_presented = dead
	var body: RigidBody3D = self as Node as RigidBody3D
	body.visible = false if dead else _living_visible
	body.collision_layer = 0 if dead else _living_layer
	body.collision_mask = 0 if dead else _living_mask
	body.freeze = true if dead else _living_freeze
	sync_navigation_lifecycle(not dead)
	if dead and animation_player != null:
		animation_player.stop()


#endregion

#region Callbacks атакующей анимации
## Callback method-track публикует запрос эффекта; Combat подключает текущее исполнение.
func npc_attack_hit() -> void:
	if not Engine.is_editor_hint():
		attack_effect_requested.emit()


## Callback method-track публикует запрос завершения текущего исполнения Combat.
func npc_attack_finished() -> void:
	if not Engine.is_editor_hint():
		attack_finish_requested.emit()

#endregion

#region Сообщение физического участника
## Обновляет необязательную Label3D Message; факты визита не изменяет.
func show_message(message: String) -> void:
	var label: Label3D = get_node_or_null("Message") as Label3D
	if label != null:
		label.text = message
#endregion
