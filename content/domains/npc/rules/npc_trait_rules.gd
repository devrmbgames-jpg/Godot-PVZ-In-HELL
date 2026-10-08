extends RefCounted
## Read-only gaze/vulnerability decisions; exposure and retreat clocks belong to the trait System.
class_name NpcTraitRules

#region Observed trait predicates
## Tests the current player view against the authored gaze requirement.
static func gazing(player: Entity, actor: E_DistrictNpc, rule: DEF_NpcTrait) -> bool:
	var spatial: Node3D = player as Node as Node3D
	if spatial == null or spatial.global_position.distance_to(actor.global_position) > rule.radius * 3.0:
		return false

	var camera: Camera3D = spatial.get_viewport().get_camera_3d()
	if camera == null:
		return false
	return -camera.global_basis.z.dot((actor.global_position + Vector3.UP * NpcPerceptionService.EYE_HEIGHT - camera.global_position).normalized()) >= rule.gaze_alignment

## Reads the latest observed confrontation response and visible held weapon.
static func looks_vulnerable(player: Entity, person: NpcRecord) -> bool:
	var held: Entity = GrabService.held_object(player)
	if held != null and held.has_component(C_MeleeWeapon):
		return false

	for index: int in range(person.memories.size() - 1, -1, -1):
		var memory: NpcMemory = person.memories[index]
		if memory.actor_id != &"player":
			continue
		if memory.kind == NpcMemory.Kind.SUBMISSION:
			return true
		if memory.reaction == NpcMemory.Reaction.RESPECT or memory.kind == NpcMemory.Kind.KILLING:
			return false
	return true
#endregion
