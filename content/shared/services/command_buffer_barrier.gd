extends RefCounted
## Bounded explicit command quiescence for ready/restore/capture; never advances scheduled ticks.
class_name CommandBufferBarrier


#region Explicit quiescence barrier
## Drains structural/outcome commands without running a scheduled tick.
## A non-settling reaction chain rejects capture instead of saving partial state.
static func drain_pending(world: World) -> bool:
	const MAX_DRAIN_PASSES: int = 32
	for _pass_index: int in MAX_DRAIN_PASSES:
		var pending: bool = false
		for owner: System in world.systems:
			if owner.has_pending_commands():
				pending = true
				owner.cmd.execute()
		for owner: Observer in world.observers:
			if owner.has_pending_commands():
				pending = true
				owner.cmd.execute()
		if not pending:
			return true
	return false
#endregion
