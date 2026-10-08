extends Component
## Параметры одного физического предмета в слоте; при креплении его симуляция приостанавливается.
class_name C_PhysicalSlot

## Необязательное требование к одному реальному предмету для помещения в слот.
@export var filter: DEF_AccessRequirement = null
## Максимальная допустимая масса предмета в килограммах.
@export_range(0.01, 100.0, 0.01) var maximum_mass: float = 8.0
## Разрешает замену предмета в занятой руке при извлечении из слота.
@export var allow_hand_replacement: bool = false
