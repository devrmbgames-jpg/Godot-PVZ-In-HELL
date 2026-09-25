extends GameDefinition
## Immutable generic hazard tuning embedded by an autonomous hazard scene.
class_name DEF_Hazard

enum Ownership {
	Independent,
	FollowOrigin,
}
enum OwnerLoss {
	Detach,
	Despawn,
}

## Finite lifetime in simulation seconds; persistent only controls future nightly reset.
@export_range(0.05, 3600.0) var lifetime_seconds: float = 10.0
@export var persistent: bool = false
## Follow applies to the spawned non-rigid effect, never to its initiating physics body.
@export var ownership: Ownership = Ownership.Independent
@export var owner_loss: OwnerLoss = OwnerLoss.Detach
