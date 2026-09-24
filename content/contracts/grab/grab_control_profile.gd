extends RefCounted
## Effective physical holding policy. C_Grabbable may override these defaults.
class_name GrabControlProfile

var allowed_hand_slots: int = 0
var manual_rotation_enabled: bool = true
var rotation_axis: C_Grabbable.RotationAxis = C_Grabbable.RotationAxis.FREE
var reset_rotation_on_pickup: bool = false
var hold_distance: float = -1.0
var position_stiffness: float = 110.0
var position_damping: float = 22.0
var max_hold_force: float = 12000.0
var break_distance: float = 4.0
var throw_velocity: float = 10.0
var max_rotation_speed: float = 30.0
var movement_speed_multiplier: float = 1.0
var movement_acceleration_multiplier: float = 1.0


static func from_grabbable(config: C_Grabbable) -> GrabControlProfile:
	var profile: GrabControlProfile = GrabControlProfile.new()
	if config == null:
		return profile
	profile.allowed_hand_slots = config.allowed_hand_slots
	profile.manual_rotation_enabled = config.manual_rotation_enabled
	profile.rotation_axis = config.rotation_axis
	profile.reset_rotation_on_pickup = config.reset_rotation_on_pickup
	profile.hold_distance = config.hold_distance
	profile.position_stiffness = config.position_stiffness
	profile.position_damping = config.position_damping
	profile.max_hold_force = config.max_hold_force
	profile.break_distance = config.break_distance
	profile.throw_velocity = config.throw_velocity
	profile.max_rotation_speed = config.max_rotation_speed
	profile.movement_speed_multiplier = config.movement_speed_multiplier
	profile.movement_acceleration_multiplier = config.movement_acceleration_multiplier
	return profile
