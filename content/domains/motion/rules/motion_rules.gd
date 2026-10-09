extends RefCounted
## Pure locomotion limits shared by scheduled intent and both native physical adapters.
class_name MotionRules

const DEFAULT_FRICTION: float = 1.0

#region Shared locomotion calculations
## Speed in metres per second from authored speed, sprint, carry Strength and hunger policies.
static func effective_speed(
	motion: C_Motion,
	carry_load: C_CarryLoad,
	strength: C_Strength,
	hunger: C_Hunger = null,
) -> float:
	var carry_multiplier: float = 1.0
	if carry_load != null and carry_load.active:
		carry_multiplier = CarryLoadPolicy.active_multiplier(carry_load, strength)
	return motion.max_speed * motion.sprint_multiplier * carry_multiplier * HungerRules.speed_multiplier(hunger)


## Computes control traction from an optional authored support material.
static func surface_traction(surface_material: PhysicsMaterial) -> float:
	return surface_material.friction if surface_material != null else DEFAULT_FRICTION
#endregion
