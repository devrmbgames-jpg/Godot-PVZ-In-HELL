# Player interaction events

Subscribe through the existing GECS World channel `PlayerInteractionEvent.EVENT`
(`player_interaction`). The event entity is the affected terminal/parcel/openable;
the payload is a `PlayerInteractionEvent`, with `actor`, `object`, stable IDs,
`package_id` when applicable and one of six `Kind` values.

| Kind | Committed boundary |
| --- | --- |
| TERMINAL_OPENED / TERMINAL_CLOSED | Actual panel visibility/capture change |
| PARCEL_PICKED | Accepted physical grip, including relationship producers |
| PARCEL_PLACED | Player release, placement, transfer or throw; floor contact is not implied |
| DOOR_OPENED / DOOR_CLOSED | Native physical fraction reaches the requested endpoint within2% |

Example observer subscription:

```gdscript
func query() -> QueryBuilder:
	return q.with_all([C_Openable]).on_event(PlayerInteractionEvent.EVENT)

func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var transition: PlayerInteractionEvent = payload as PlayerInteractionEvent
	if transition == null or transition.object != entity:
		return
	if transition.kind == PlayerInteractionEvent.Kind.DOOR_OPENED:
		# Queue future behavior through cmd; do not move the native door body here.
		pass
```

Only actors with `C_PlayerInputController` publish player actions. Failed/repeated
requests and parcel cleanup do not masquerade as player placement. Pending door
attribution is a transient `R_OpenableRequestedBy` Relationship, canceled at load
and Night reset. Events are not serialized or replayed. Downstream subscribers
must validate live references; stable IDs remain useful after object removal.
