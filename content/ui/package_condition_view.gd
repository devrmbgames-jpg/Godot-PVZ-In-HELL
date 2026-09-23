extends Label3D
## Read-only world feedback for package condition; never changes gameplay state.
class_name PackageConditionView

## Authored colors for persistent condition labels.
@export var damaged_color: Color = Color(1.0, 0.68, 0.2)
@export var destroyed_color: Color = Color(1.0, 0.25, 0.2)
@export var opened_color: Color = Color(1.0, 0.93, 0.7)
@export var leaking_color: Color = Color(0.3, 0.85, 1.0)

var _damage: int = -1
var _opening: int = -1
var _leaking: bool = false
@onready var _package: Entity = get_parent() as Entity


func _process(_delta: float) -> void:
	if not is_instance_valid(_package):
		visible = false
		return
	var condition: C_PackageState = _package.get_component(C_PackageState) as C_PackageState
	if condition == null:
		visible = false
		return
	var unchanged: bool = (
		_damage == condition.damage and _opening == condition.opening
		and _leaking == condition.leaking
	)
	if unchanged:
		return
	_damage = condition.damage
	_opening = condition.opening
	_leaking = condition.leaking

	var lines: PackedStringArray = []
	modulate = opened_color
	if condition.opening == C_PackageState.Opening.OPENED:
		lines.append("Вскрыта")
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
