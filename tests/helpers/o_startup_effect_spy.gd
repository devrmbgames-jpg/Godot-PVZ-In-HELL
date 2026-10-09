extends Observer
## Effectful fixture reaction detects whether prefab defaults were published before restored readiness.
class_name O_StartupEffectSpy

## Number of actual gameplay reaction dispatches.
var effects: int = 0

#region Structural effect detection
## Monitors actual Health membership at registration and later gameplay mutations.
func query() -> QueryBuilder:
	return q.with_all([C_Health]).on_match()


## Records dispatches without depending on observer flags or snapshot implementation details.
func each(_event: Variant, _actor: Entity, _payload: Variant = null) -> void:
	effects += 1
#endregion
