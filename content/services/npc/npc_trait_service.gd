extends RefCounted
## Explicit immunity/aura installation and authored refuge lookup; trait clocks belong to S_NpcTraits.
class_name NpcTraitService

## Authored effect prefab for explicit fire-aura materialization.
const AURA_SCENE: String = "res://content/entities/hazards/npc_fire_aura.tscn"

#region Жизненный цикл особенностей
## Устанавливает настоящий иммунитет к огню до воздействия собственной ауры.
static func install(actor: E_DistrictNpc, profile: DEF_NpcProfile) -> void:
	var resistance: C_DamageResistance = actor.get_component(C_DamageResistance) as C_DamageResistance
	if resistance == null:
		resistance = C_DamageResistance.new()
		actor.add_component(resistance)
	if profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null:
		resistance.multipliers[DamageRequest.Type.FIRE] = 0.0

## Использует авторское укрытие от света или закреплённую точку выхода личности.
static func dark_refuge(_actor: E_DistrictNpc, person: NpcRecord) -> Vector3:
	var district: C_District = DistrictPopulationService.current()
	var refuge_id: StringName = district.definition.shade_refuge
	if district.definition.place_for(refuge_id) == null:
		refuge_id = person.portal_id
	return DistrictPopulationService.position_for(refuge_id)


## Materializes one missing authored aura; repeated explicit calls cannot duplicate it.
static func ensure_aura(actor: E_DistrictNpc, person: NpcRecord, rule: DEF_NpcTrait) -> void:
	if rule.aura == null:
		return

	for entity: Entity in ECS.world.query.with_all([C_Hazard, C_HazardLifetime]).execute():
		var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
		var life: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
		if hazard.origin_id == String(person.npc_id) and life.remaining_seconds > 0.0:
			return

	var district: C_District = DistrictPopulationService.current()
	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.request_id = "aura/%s/%d" % [person.npc_id, district.next_aura]
	district.next_aura += 1
	request.origin_id = String(person.npc_id)
	request.origin = actor
	request.instigator = actor
	request.instigator_id = String(person.npc_id)
	request.scene = load(AURA_SCENE) as PackedScene
	request.definition = rule.aura
	request.world_pose = actor.global_transform
	request.world_pose.origin += Vector3.UP * NpcPerceptionService.TORSO_HEIGHT
	HazardSpawnService.submit(request)
#endregion
