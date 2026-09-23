extends RefCounted
## Narrow imperative seam for deliberate throw and pickup transitions.
class_name ThrowContext


## Arms only after an actual grip release and nonzero throw impulse.
static func arm(source: Entity, instigator: Entity) -> void:
	var context: C_ThrowDamage = source.get_component(C_ThrowDamage) as C_ThrowDamage
	if context == null:
		return
	context.instigator = instigator
	context.remaining_seconds = maxf(0.0, context.window_seconds)
	context.armed_tick = Engine.get_physics_frames()


## A new grip cancels any old throw attribution immediately.
static func cancel(source: Entity) -> void:
	if not is_instance_valid(source):
		return
	var context: C_ThrowDamage = source.get_component(C_ThrowDamage) as C_ThrowDamage
	if context != null:
		context.remaining_seconds = 0.0
		context.instigator = null
