extends RefCounted
## Read-only sampled light constraint; no sensing, clocks or target mutation.
class_name NpcDarknessQueries


#region Sampled constraint
## Attack boundaries share the due-step trait fact even when another native branch preempts calm.
static func combat_suppressed(actor: Entity) -> bool:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	return awareness != null and awareness.darkness_combat_suppressed
#endregion
