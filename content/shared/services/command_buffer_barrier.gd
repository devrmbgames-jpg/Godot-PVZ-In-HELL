extends RefCounted
## Bounded explicit command quiescence for ready/restore/capture; never advances scheduled ticks.
class_name CommandBufferBarrier


#region Explicit quiescence barrier
## Read-only pinned GECS v8 adapter: execute() detaches its queue before running callbacks.
## Empty buffers alone therefore cannot certify a snapshot boundary. The native suppression
## depth covers the executing batch (also rejecting other incomplete native batch mutations).
static func is_executing(world: World) -> bool:
	var suppression_depth: int = int(world.get(&"_suppress_invalidation_depth"))
	return suppression_depth > 0


## Checks execution and queued work without flushing, clearing or advancing simulation.
## Only an explicit owner that finished its mutation and drained dependent commands may certify
## its enclosing batch as settled; ordinary callers must retain the default false.
static func is_quiescent(world: World, enclosing_batch_settled: bool = false) -> bool:
	if not enclosing_batch_settled and is_executing(world):
		return false
	for owner: System in world.systems:
		if owner.has_pending_commands():
			return false
	for owner: Observer in world.observers:
		if owner.has_pending_commands():
			return false
	return true


## Drains structural/outcome commands without running a scheduled tick.
## A non-settling reaction chain rejects capture instead of saving partial state.
## true requires an observed pass with no pending commands, within 32 passes including that check.
## false does not roll back commands already executed; it certifies no quiescent boundary.
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
