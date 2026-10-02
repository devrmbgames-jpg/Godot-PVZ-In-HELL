extends RefCounted
## Presentation snapshot, valid after the damaged Entity is removed. No live references.
class_name DamageFeedback

enum Audience { PLAYER, PACKAGE, OTHER }

var audience: Audience = Audience.OTHER
var target_id: String = ""
var package_id: String = ""
var damage_type: DamageRequest.Type = DamageRequest.Type.GENERIC
var amount: float = 0.0
var position: Vector3 = Vector3.ZERO
var depleted: bool = false
var actor_is_player: bool = false
