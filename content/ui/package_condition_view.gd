extends Label3D
## Показывает состояние коробки в мире, читая компоненты без изменения игровых данных.
class_name PackageConditionView

## Цвет метки повреждённой коробки.
@export var damaged_color: Color = Color(1.0, 0.68, 0.2)
## Цвет метки уничтоженной коробки.
@export var destroyed_color: Color = Color(1.0, 0.25, 0.2)
## Цвет вскрытия и исходный цвет наклеек.
@export var opened_color: Color = Color(1.0, 0.93, 0.7)
## Цвет метки протекающей коробки.
@export var leaking_color: Color = Color(0.3, 0.85, 1.0)
## Мировой размер пикселя наклеек, в метрах.
@export var face_label_pixel_size: float = 0.0018
## Отступ наклеек от грани модели, в метрах.
@export var face_label_offset: float = 0.003

var _damage: int = -1
var _opening: int = -1
var _leaking: bool = false
var _empty: bool = false
var _definition: DEF_Package = null
var _stickers: Array[Label3D] = []
@onready var _package: Entity = get_parent() as Entity


#region Создание наклеек
func _ready() -> void:
	_create_stickers.call_deferred()


func _create_stickers() -> void:
	var package_entity: E_Package = _package as E_Package
	if package_entity == null:
		return

	var surface: MeshInstance3D = package_entity.get_marking_surface()
	if surface == null:
		return

	var bounds: AABB = surface.get_aabb()
	var center: Vector3 = bounds.get_center()
	var half: Vector3 = bounds.size * 0.5
	var positions: Array[Vector3] = [center + Vector3(0, 0, half.z + face_label_offset), center - Vector3(0, 0, half.z + face_label_offset), center + Vector3(half.x + face_label_offset, 0, 0), center - Vector3(half.x + face_label_offset, 0, 0)]
	var turns: Array[float] = [0.0, PI, PI * 0.5, -PI * 0.5]
	for index: int in positions.size():
		var sticker: Label3D = Label3D.new()
		sticker.name = "PackageLabel%d" % index
		sticker.font_size = 32
		sticker.pixel_size = face_label_pixel_size
		sticker.outline_size = 6
		sticker.position = positions[index]
		sticker.rotation.y = turns[index]
		sticker.modulate = opened_color
		surface.add_child(sticker)
		_stickers.append(sticker)
	_damage = -1


#endregion

#region Обновление состояния
func _process(_delta: float) -> void:
	if not is_instance_valid(_package):
		visible = false
		return

	var condition: C_PackageState = _package.get_component(C_PackageState) as C_PackageState
	var package_data: C_Package = _package.get_component(C_Package) as C_Package
	if condition == null or package_data == null:
		visible = false
		return

	var unchanged: bool = (
		_damage == condition.damage and _opening == condition.opening
		and _leaking == condition.leaking
		and _definition == package_data.definition
		and _empty == PackageContentsService.is_empty(_package)
	)
	if unchanged:
		return

	_damage = condition.damage
	_opening = condition.opening
	_leaking = condition.leaking
	_definition = package_data.definition
	_empty = PackageContentsService.is_empty(_package)

	var lines: PackedStringArray = []
	modulate = opened_color
	if condition.opening == C_PackageState.Opening.OPENED:
		lines.append("Пустая коробка" if _empty else "Вскрыта")
	if condition.leaking:
		lines.append("Протекает")
		modulate = leaking_color
	if condition.damage == C_PackageState.Damage.DAMAGED:
		lines.append("Повреждена")
		modulate = damaged_color
	elif condition.damage == C_PackageState.Damage.DESTROYED:
		lines.append("Разрушена")
		modulate = destroyed_color
	text = " · ".join(lines)
	visible = not lines.is_empty()

	var marking: PackedStringArray = []
	if _definition != null and not _empty:
		if _definition.tags & DEF_Package.Tag.FRAGILE:
			marking.append("ХРУПКОЕ")
		if _definition.tags & DEF_Package.Tag.HEAVY:
			marking.append("ТЯЖЁЛОЕ")
		if _definition.tags & DEF_Package.Tag.LIQUID:
			marking.append("ЖИДКОСТЬ")
	marking.append_array(lines)
	for sticker: Label3D in _stickers:
		sticker.text = "\n".join(marking)
		sticker.modulate = modulate
		sticker.visible = not marking.is_empty()

#endregion
