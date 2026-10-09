extends RefCounted
## Explicit diagnostic writer and read provider; no scheduler, event bus or gameplay authority.
class_name BoundaryTrace

const MAX_ENTRIES: int = 128

#region Correlation and recording
## Allocates transient correlation only; callers retain their durable transaction IDs.
static func next_id(operation: StringName) -> StringName:
	var trace_state: C_BoundaryTrace = _state()
	if trace_state == null:
		return &""

	var correlation: StringName = StringName("%s/%d" % [operation, trace_state.next_correlation])
	trace_state.next_correlation += 1
	return correlation


## Records a committed diagnostic snapshot; an absent optional provider has no gameplay effect.
static func record(
	operation: StringName,
	correlation_id: StringName,
	stage: BoundaryTraceEntry.Stage,
	reason: StringName,
	origin_id: String = "",
	target_id: String = "",
) -> void:
	var trace_state: C_BoundaryTrace = _state()
	if trace_state == null:
		return

	var entry: BoundaryTraceEntry = BoundaryTraceEntry.new()
	entry.sequence = trace_state.next_sequence
	entry.operation = operation
	entry.correlation_id = correlation_id
	entry.stage = stage
	entry.reason = reason
	entry.origin_id = origin_id
	entry.target_id = target_id
	trace_state.next_sequence += 1
	trace_state.entries.append(entry)
	if trace_state.entries.size() > MAX_ENTRIES:
		trace_state.entries.pop_front()
#endregion

#region Read provider
## Reads detached snapshots for all operations or a single explicit target identity.
static func snapshots(target_id: String = "") -> Array[Dictionary]:
	var snapshots_out: Array[Dictionary] = []
	var trace_state: C_BoundaryTrace = _state()
	if trace_state != null:
		for entry: BoundaryTraceEntry in trace_state.entries:
			if target_id.is_empty() or entry.target_id == target_id:
				snapshots_out.append(entry.snapshot())
	return snapshots_out


static func _state() -> C_BoundaryTrace:
	# Diagnostics is optional in isolated Worlds; normal level composition installs it once.
	if not is_instance_valid(ECS.world):
		return null
	var session: Entity = ECS.world.query.with_all([C_BoundaryTrace]).execute_one()
	return session.get_component(C_BoundaryTrace) as C_BoundaryTrace if session != null else null
#endregion
