extends CanvasLayer

@export var player: Entity = null
@export var debug_status_enabled: bool = true
@onready var prompt: Label = $Overlay/Prompt
@onready var phase_label: Label = $Overlay/StatusPanel/DayPhase
@onready var announcement: Label = $Overlay/Announcement
@onready var crosshair: Label = $Overlay/Crosshair
@onready var player_debug_panel: PanelContainer = $Overlay/PlayerDebugPanel
@onready var player_health_label: Label = $Overlay/PlayerDebugPanel/Debug/HealthLabel
@onready var player_health_bar: ProgressBar = $Overlay/PlayerDebugPanel/Debug/HealthBar
@onready var package_debug_panel: PanelContainer = $Overlay/PackageDebugPanel
@onready var package_type_label: Label = $Overlay/PackageDebugPanel/Debug/TypeLabel
@onready var package_health_label: Label = $Overlay/PackageDebugPanel/Debug/HealthLabel
@onready var package_health_bar: ProgressBar = $Overlay/PackageDebugPanel/Debug/HealthBar

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
	_refresh_phase_presentation()
	_update_debug_presentation(null)


func _process(delta: float) -> void:
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	prompt.visible = captured
	crosshair.visible = (
		captured
		and InteractionControlFocus.current(player) != InteractionControlFocus.Priority.DRAWING
	)
	_announcement_remaining = maxf(0.0, _announcement_remaining - delta)
	announcement.visible = _announcement_remaining > 0.0

	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle != null:
		if cycle.day_index != _last_day_index or cycle.phase != _last_phase:
			_on_phase_changed(cycle.day_index, cycle.phase)
		phase_label.text = "ЦИКЛ %d  •  %s\n%s" % [
			cycle.day_index,
			PHASE_NAMES[cycle.phase],
			PHASE_HINTS[cycle.phase],
		]
	else:
		_last_day_index = -1
		_last_phase = -1
		phase_label.text = ""

	if not GrabService.holder_available(player):
		prompt.text = ""
		_update_debug_presentation(null)
		return
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	prompt.text = interactor.prompt_text if interactor != null else ""
	_update_debug_presentation(interactor.target if interactor != null else null)
#endregion


#region Debug acceptance presentation
func _update_debug_presentation(target: Entity) -> void:
	if not debug_status_enabled:
		player_debug_panel.visible = false
		package_debug_panel.visible = false
		return
	_update_player_health_debug()
	_update_package_debug(target)


func _update_player_health_debug() -> void:
	if not is_instance_valid(player):
		player_debug_panel.visible = false
		return
	var health: C_Health = player.get_component(C_Health) as C_Health
	if health == null:
		player_debug_panel.visible = false
		return
	player_debug_panel.visible = true
	var values: Vector2 = _update_health_bar(player_health_bar, health)
	player_health_label.text = "PLAYER HP  %.1f / %.1f" % [values.x, values.y]


func _update_package_debug(target: Entity) -> void:
	if not is_instance_valid(target):
		package_debug_panel.visible = false
		return
	var package: C_Package = target.get_component(C_Package) as C_Package
	if package == null:
		package_debug_panel.visible = false
		return

	package_debug_panel.visible = true
	package_type_label.text = _package_debug_text(package.definition)

	var health: C_Health = target.get_component(C_Health) as C_Health
	var has_health: bool = health != null
	package_health_label.visible = has_health
	package_health_bar.visible = has_health
	if not has_health:
		return
	var values: Vector2 = _update_health_bar(package_health_bar, health)
	package_health_label.text = "HP  %.1f / %.1f" % [values.x, values.y]


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

	var hazard: String = "Нет"
	match definition.hazard:
		DEF_Package.Hazard.TOXIC:
			hazard = "Токсичная"
		DEF_Package.Hazard.EXPLOSIVE:
			hazard = "Взрывная"

	return "ПОСЫЛКА: %s\nОПАСНОСТЬ: %s" % [" · ".join(tags), hazard]
#endregion


#region Presentation callbacks
func _refresh_phase_presentation() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle != null:
		_on_phase_changed(cycle.day_index, cycle.phase)


func _on_phase_changed(day_index: int, phase: C_DayCycle.Phase) -> void:
	_last_day_index = day_index
	_last_phase = phase
	announcement.text = "%s\nЦикл %d · %s" % [
		ANNOUNCEMENTS[phase],
		day_index,
		PHASE_NAMES[phase],
	]
	_announcement_remaining = ANNOUNCEMENT_SECONDS
#endregion
