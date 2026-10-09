extends CanvasLayer
## Обновляет список вечерних доставок с паузой; обещания, коробки и деньги принадлежат сервисам.
class_name DistrictDeliveryView

const REFRESH_SECONDS: float = 0.5
const SAFE_MARGIN: float = 16.0
const HUD_TOP: float = 140.0
const MAXIMUM_WIDTH: float = 560.0

var _label: Label = null
var _elapsed: float = 0.0

#region Отображение
func _ready() -> void:
	layer = 12
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	get_viewport().size_changed.connect(_place_label)
	_place_label()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= REFRESH_SECONDS:
		_elapsed = 0.0
		_label.text = NpcHomeDeliveryService.status_text()
		_label.visible = not _label.text.is_empty()

func _place_label() -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var width: float = minf(MAXIMUM_WIDTH, viewport_width * 0.45)
	_label.offset_left = -width - SAFE_MARGIN
	_label.offset_right = -SAFE_MARGIN
	_label.offset_top = HUD_TOP
	_label.offset_bottom = HUD_TOP
#endregion
