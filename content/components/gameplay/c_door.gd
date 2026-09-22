extends Component
class_name C_Door




@export var locked := false
@export var auto_closed := false




var hinge_joint: HingeJoint3D = null
var door_root: Node3D = null
