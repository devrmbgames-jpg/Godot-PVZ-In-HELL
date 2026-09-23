extends RefCounted
## One committed depletion effect notification; presentation may consume optional VFX/SFX.
class_name HealthDepletionEvent

## World event emitted after gameplay spawn entries have been dispatched.
const EVENT: StringName = &"health_depletion_effects"

## Original cause and stable world pose, valid even if the original target leaves the World.
var cause: DamageResult = null
var world_pose: Transform3D = Transform3D.IDENTITY
## Optional presentation hooks; presentation never owns gameplay spawn or damage.
var vfx: PackedScene = null
var sfx: AudioStream = null
