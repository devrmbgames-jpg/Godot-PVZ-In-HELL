extends Component
## Authored destruction mode; remaining HP belongs solely to C_Health.
class_name C_BreakableDoor

enum Mode { LEAF, PADLOCK }

@export var mode: Mode = Mode.LEAF
