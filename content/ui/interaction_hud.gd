extends CanvasLayer

@export var player: Entity = null
@export var debug_status_enabled: bool = true
@export var challenge_debug_enabled: bool = true
@export var reduced_gaze_motion: bool = true
@export var player_status_enabled: bool = true
@export var damage_feedback: O_DamageFeedback = null
@onready var _damage_view: DamageFeedbackView = $DamageFeedback
@onready var _feedback_debug: Label = $Overlay/PlayerDebugPanel/Debug/FeedbackDebug
@onready var _player_status: PanelContainer = $Overlay/PlayerStatusPanel
@onready var _status_health: Label = $Overlay/PlayerStatusPanel/Stats/Health
@onready var _status_health_bar: ProgressBar = $Overlay/PlayerStatusPanel/Stats/HealthBar
@onready var _status_hunger: Label = $Overlay/PlayerStatusPanel/Stats/Hunger
@onready var _status_hunger_bar: ProgressBar = $Overlay/PlayerStatusPanel/Stats/HungerBar
@onready var _status_money: Label = $Overlay/PlayerStatusPanel/Stats/Money
@onready var _prompt: Label = $Overlay/Prompt
@onready var _phase_label: Label = $Overlay/StatusPanel/DayPhase
@onready var _announcement: Label = $Overlay/Announcement
@onready var _crosshair: Label = $Overlay/Crosshair
@onready var _interaction_progress: ProgressBar = $Overlay/InteractionProgress
@onready var _challenge_status: Label = $Overlay/ChallengeStatus
@onready var _challenge_debug_panel: PanelContainer = $Overlay/ChallengeDebugPanel
@onready var _challenge_debug_text: Label = $Overlay/ChallengeDebugPanel/Text
@onready var _gaze_distortion: ColorRect = $Overlay/GazeDistortion
@onready var _gaze_warning: Label = $Overlay/GazeWarning
@onready var _gaze_progress: ProgressBar = $Overlay/GazeWarningProgress
@onready var _player_debug_panel: PanelContainer = $Overlay/PlayerDebugPanel
@onready var _player_health_label: Label = $Overlay/PlayerDebugPanel/Debug/HealthLabel
@onready var _player_health_bar: ProgressBar = $Overlay/PlayerDebugPanel/Debug/HealthBar
@onready var _combat_debug: Label = $Overlay/PlayerDebugPanel/Debug/CombatDebug
@onready var _meta_debug: Label = $Overlay/PlayerDebugPanel/Debug/MetaDebug
@onready var _inventory_debug: Label = $Overlay/PlayerDebugPanel/Debug/InventoryDebug
@onready var _hunger_debug: Label = $Overlay/PlayerDebugPanel/Debug/HungerDebug
@onready var _package_debug_panel: PanelContainer = $Overlay/PackageDebugPanel
@onready var _package_type_label: Label = $Overlay/PackageDebugPanel/Debug/TypeLabel
@onready var _package_health_label: Label = $Overlay/PackageDebugPanel/Debug/HealthLabel
@onready var _package_health_bar: ProgressBar = $Overlay/PackageDebugPanel/Debug/HealthBar

const PHASE_NAMES: Array[String] = ["Утро", "День", "Вечер", "Ночь"]
const PHASE_HINTS: Array[String] = [
	"Приёмка · Сканер на столе; ЛКМ — регистрация. Пульт — начало смены.",
	"Смена идёт · Завершите обслуживание и закройте смену на пульте",
	"Смена завершена · Место отдыха доступно для сна",
	"Завершение дня…",
]
const ANNOUNCEMENTS: Array[String] = [
	"Новое утро",
	"СМЕНА НАЧАЛАСЬ",
	"СМЕНА ЗАВЕРШЕНА",
	"Наступила ночь",
]
const ANNOUNCEMENT_SECONDS: float = 4.0
const MINIMUM_HEALTH_BAR_MAXIMUM: float = 0.001

var _announcement_remaining: float = 0.0
var _last_day_index: int = -1
var _last_phase: int = -1


#region Lifecycle
func _ready() -> void:
	_damage_view.player = player
	_damage_view.observer = damage_feedback
	_damage_view.bind_observer()
	_refresh_phase_presentation()
	_update_debug_presentation(null)


func _process(delta: float) -> void:
	_update_player_status()
	var show_debug: bool = debug_status_enabled and DebugHudService.is_enabled()
	_feedback_debug.text = _compact_debug(_damage_view.debug_text()) if show_debug else ""
	_combat_debug.text = _compact_debug(CombatPresentation.debug_text(player)) if show_debug else ""
	_meta_debug.text = _compact_debug(MetaPresentation.debug_text()) if show_debug else ""
	_inventory_debug.text = _compact_debug(InventoryPresentation.debug_text(player)) if show_debug else ""
	_hunger_debug.text = _compact_debug(HungerPresentation.debug_text(player)) if show_debug else ""
	_update_gaze_warning()
	_challenge_status.text = ChallengePresentation.text_for(player)
	_challenge_status.visible = not _challenge_status.text.is_empty()
	_challenge_debug_panel.visible = challenge_debug_enabled and DebugHudService.is_enabled()
	if _challenge_debug_panel.visible:
		_challenge_debug_text.text = "Клиенты: %d\nТаймеры, условия и задачи — над NPC" % (ECS.world.query.with_all([C_CustomerAgent]).execute().size() if is_instance_valid(ECS.world) else 0)
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var progress: ProlongedInteractionProgress = ProlongedInteractionService.active_progress(player)
	_interaction_progress.visible = captured and progress != null
	_interaction_progress.value = progress.fraction if progress != null else 0.0
	_prompt.visible = captured
	_crosshair.visible = (
		captured
		and InteractionControlFocus.current(player) != InteractionControlFocus.Priority.DRAWING
	)
	_announcement_remaining = maxf(0.0, _announcement_remaining - delta)
	_announcement.visible = _announcement_remaining > 0.0

	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle != null:
		if cycle.day_index != _last_day_index or cycle.phase != _last_phase:
			_on_phase_changed(cycle.day_index, cycle.phase)
		_phase_label.text = "ЦИКЛ %d  •  %s\n%s" % [
			cycle.day_index,
			PHASE_NAMES[cycle.phase],
			PHASE_HINTS[cycle.phase],
		]
	else:
		_last_day_index = -1
		_last_phase = -1
		_phase_label.text = ""

	if not GrabService.holder_available(player):
		_prompt.text = ""
		_update_debug_presentation(null)
		return
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	_prompt.text = interactor.prompt_text if interactor != null else ""
	_update_debug_presentation(interactor.target if interactor != null else null)
#endregion


func _update_player_status() -> void:
	_player_status.visible = player_status_enabled and is_instance_valid(player)
	if not _player_status.visible:
		return
	var health: C_Health = player.get_component(C_Health) as C_Health
	_status_health.visible = health != null
	_status_health_bar.visible = health != null
	if health != null:
		var values: Vector2 = _update_health_bar(_status_health_bar, health)
		_status_health.text = "Здоровье  %.0f / %.0f%s" % [values.x, values.y, " · Вы повержены" if health.depleted else ""]
	var hunger: C_Hunger = player.get_component(C_Hunger) as C_Hunger
	var has_hunger: bool = hunger != null and hunger.policy != null
	_status_hunger.visible = has_hunger
	_status_hunger_bar.visible = has_hunger
	if has_hunger:
		const HUNGER_NAMES: Array[String] = ["Сыт", "Голоден", "Сильный голод"]
		_status_hunger.text = "Голод  %.0f / %.0f · %s" % [hunger.value, hunger.policy.maximum, HUNGER_NAMES[HungerService.tier(hunger)]]
		_status_hunger_bar.max_value = hunger.policy.maximum
		_status_hunger_bar.value = hunger.value
	var wallet: C_Wallet = WalletService.current()
	_status_money.visible = wallet != null
	if wallet != null:
		_status_money.text = "Баланс  %d ₽ · Штрафы  %d ₽" % [wallet.balance, wallet.penalties]


#region Debug acceptance presentation
func _compact_debug(message: String) -> String:
	var lines: PackedStringArray = message.split("\n")
	return lines[0] if not lines.is_empty() else ""


func _update_debug_presentation(target: Variant) -> void:
	if not debug_status_enabled or not DebugHudService.is_enabled():
		_player_debug_panel.visible = false
		_package_debug_panel.visible = false
		return
	_update_player_health_debug()
	_update_package_debug(target)


func _update_player_health_debug() -> void:
	if not is_instance_valid(player):
		_player_debug_panel.visible = false
		return
	var health: C_Health = player.get_component(C_Health) as C_Health
	if health == null:
		_player_debug_panel.visible = false
		return
	_player_debug_panel.visible = true
	var values: Vector2 = _update_health_bar(_player_health_bar, health)
	_player_health_label.text = "PLAYER HP  %.1f / %.1f" % [values.x, values.y]


func _update_gaze_warning() -> void:
	var state: C_Challenge = GazeChallengePresentation.state_for(player)
	var strength: float = GazeChallengePresentation.strength(state)
	_gaze_distortion.visible = strength > 0.0
	var material: ShaderMaterial = _gaze_distortion.material as ShaderMaterial
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("reduced_motion", reduced_gaze_motion)
	_gaze_warning.text = GazeChallengePresentation.text(state)
	_gaze_warning.visible = strength > 0.0
	_gaze_progress.visible = strength > 0.0
	_gaze_progress.value = strength


func _update_package_debug(target: Variant) -> void:
	if not is_instance_valid(target):
		_package_debug_panel.visible = false
		return
	var entity: Entity = target as Entity
	if entity == null:
		_package_debug_panel.visible = false
		return
	var package: C_Package = entity.get_component(C_Package) as C_Package
	if package == null:
		_package_debug_panel.visible = false
		return

	_package_debug_panel.visible = true
	_package_type_label.text = _package_debug_text(package.definition)

	var health: C_Health = entity.get_component(C_Health) as C_Health
	var has_health: bool = health != null
	_package_health_label.visible = has_health
	_package_health_bar.visible = has_health
	if not has_health:
		return
	var values: Vector2 = _update_health_bar(_package_health_bar, health)
	_package_health_label.text = "HP  %.1f / %.1f" % [values.x, values.y]


func _update_health_bar(bar: ProgressBar, health: C_Health) -> Vector2:
	var maximum: float = maxf(health.get_hp_max(), MINIMUM_HEALTH_BAR_MAXIMUM)
	var current: float = clampf(health.get_hp_current(), 0.0, maximum)
	bar.min_value = 0.0
	bar.max_value = maximum
	bar.value = current
	return Vector2(current, maximum)


func _package_debug_text(definition: DEF_Package) -> String:
	if definition == null:
		return "ПОСЫЛКА: нет definition"

	var tags: PackedStringArray = []
	if (definition.tags & DEF_Package.Tag.NORMAL) != 0:
		tags.append("Обычная")
	if (definition.tags & DEF_Package.Tag.FRAGILE) != 0:
		tags.append("Хрупкая")
	if (definition.tags & DEF_Package.Tag.HEAVY) != 0:
		tags.append("Тяжёлая")
	if (definition.tags & DEF_Package.Tag.LIQUID) != 0:
		tags.append("Жидкость")
	if tags.is_empty():
		tags.append("Без тегов")

	var damaged_hazard: String = _hazard_scene_name(definition.hazard_on_damaged)
	var destroyed_hazard: String = _hazard_scene_name(definition.hazard_on_destroyed)
	return "ПОСЫЛКА: %s\nHAZARD DAMAGE: %s\nHAZARD DESTROYED: %s" % [
		" · ".join(tags),
		damaged_hazard,
		destroyed_hazard,
	]


func _hazard_scene_name(scene: PackedScene) -> String:
	if scene == null:
		return "Нет"
	var path: String = scene.resource_path
	if not path.is_empty():
		return path.get_file().get_basename()
	return scene.resource_name if not scene.resource_name.is_empty() else "scene"
#endregion


#region Presentation callbacks
func _refresh_phase_presentation() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle != null:
		_on_phase_changed(cycle.day_index, cycle.phase)


func _on_phase_changed(day_index: int, phase: C_DayCycle.Phase) -> void:
	_last_day_index = day_index
	_last_phase = phase
	_announcement.text = "%s\nЦикл %d · %s" % [
		ANNOUNCEMENTS[phase],
		day_index,
		PHASE_NAMES[phase],
	]
	_announcement_remaining = ANNOUNCEMENT_SECONDS
#endregion
