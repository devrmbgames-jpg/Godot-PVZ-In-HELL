extends RefCounted
## Explicit aura materialization and authored refuge lookup; immunity is a construction recipe.
class_name NpcTraitService

## Authored effect prefab for explicit fire-aura materialization.
const AURA_SCENE: String = "res://content/domains/hazards/entities/npc_fire_aura.tscn"


#region Жизненный цикл особенностей
## Использует авторское укрытие от света или закреплённую точку выхода личности.
static func dark_refuge(_actor: E_DistrictNpc, person: NpcRecord) -> Vector3:
	var district: C_District = NpcPopulationQueries.current()
	var refuge_id: StringName = district.definition.shade_refuge
	if district.definition.place_for(refuge_id) == null:
		refuge_id = person.portal_id
	return NpcPopulationQueries.position_for(refuge_id)


## Reuses a live matching aura or submits a missing spawn; void is not a committed-spawn receipt.
## next_aura is consumed before HazardSpawnService.submit, including a rejected attempt.
static func ensure_aura(actor: E_DistrictNpc, person: NpcRecord, rule: DEF_NpcTrait) -> void:
	if rule.aura == null:
		return
	_ensure_fire_volume(actor, person, rule.aura, AURA_SCENE)


static func _ensure_fire_volume(
	actor: E_DistrictNpc,
	person: NpcRecord,
	definition: DEF_ToxicArea,
	scene_path: String,
) -> void:
	for entity: Entity in ECS.world.query.with_all([C_Hazard, C_HazardLifetime]).execute():
		var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
		var life: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
		if (
			hazard.origin_id == String(person.npc_id) and life.remaining_seconds > 0.0
			and hazard.definition.key == definition.key
		):
			return

	var district: C_District = NpcPopulationQueries.current()
	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.request_id = "aura/%s/%d" % [person.npc_id, district.next_aura]
	district.next_aura += 1
	request.origin_id = String(person.npc_id)
	request.origin = actor
	request.instigator = actor
	request.instigator_id = String(person.npc_id)
	request.scene = load(scene_path) as PackedScene
	request.definition = definition
	request.world_pose = actor.global_transform
	var height: float = (
		definition.floor_height * 0.5
		if definition.floor_height > 0.0
		else NpcPerceptionService.TORSO_HEIGHT
	)
	request.world_pose.origin += Vector3.UP * height
	HazardSpawnService.submit(request)
#endregion
