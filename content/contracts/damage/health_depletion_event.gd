extends RefCounted
## One committed depletion effect notification; presentation may consume optional VFX/SFX.
class_name HealthDepletionEvent

const EVENT: StringName = &"health_depletion_effects"

var cause: DamageResult = null
var world_pose: Transform3D = Transform3D.IDENTITY
## Spawned GECS entities keyed by DEF_DepletionSpawn.key.
var spawned_entities: Dictionary[StringName, Entity] = { }
var vfx: PackedScene = null
var sfx: AudioStream = null
