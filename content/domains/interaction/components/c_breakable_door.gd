extends Component
## Авторский режим разрушения двери; текущее HP принадлежит только C_Health.
class_name C_BreakableDoor

enum Mode { LEAF, PADLOCK }

## Разрушается вся створка либо только навесной замок; представление и последствия учитывают этот режим.
@export var mode: Mode = Mode.LEAF
