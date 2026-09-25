extends CanvasLayer

@export var player: Entity = null
@onready var prompt: Label = $Overlay/Prompt
@onready var phase_label: Label = $Overlay/StatusPanel/DayPhase
@onready var announcement: Label = $Overlay/Announcement
@onready var crosshair: Label = $Overlay/Crosshair

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
var _announcement_remaining: float = 0.0
var _last_day_index: int = -1
var _last_phase: int = -1


#region Lifecycle
func _ready() -> void:
	_refresh_phase_presentation()


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
		return
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	prompt.text = interactor.prompt_text if interactor != null else ""
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
