extends RefCounted
## Pure contact qualification for an authored source, independent of receiver impact armour.
class_name ContactDamageRules


#region Contact qualification
## Requires a moving positive-impulse contact and valid authored health damage.
static func qualifies(config: C_ContactDamage, contact: PhysicsContact) -> bool:
	return (
		is_finite(config.damage) and config.damage > 0.0 and is_finite(config.minimum_speed)
		and config.minimum_speed >= 0.0 and is_finite(config.minimum_impulse)
		and config.minimum_impulse >= 0.0 and is_finite(contact.normal_speed)
		and contact.normal_speed > 0.0 and is_finite(contact.normal_impulse)
		and contact.normal_impulse > 0.0 and contact.normal_speed >= config.minimum_speed
		and contact.normal_impulse >= config.minimum_impulse
	)
#endregion
