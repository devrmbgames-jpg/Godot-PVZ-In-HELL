extends RefCounted
## Intrinsic supernatural conditions, warnings and authored fire emitters on any street appearance.
class_name NpcTraitService

const AURA_SCENE: String = "res://content/entities/hazards/npc_fire_aura.tscn"

#region Trait lifecycle
## Installs actual fire immunity before the aura can affect its owner.
static func install(actor: E_DistrictNpc, profile: DEF_NpcProfile) -> void:
	var resistance: C_DamageResistance = actor.get_component(C_DamageResistance) as C_DamageResistance
	if resistance == null:
		resistance = C_DamageResistance.new()
		actor.add_component(resistance)
	if profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null:
		resistance.multipliers[DamageRequest.Type.FIRE] = 0.0

## Evaluates sustained observable conditions at the shared perception cadence.
static func tick(actor: E_DistrictNpc, person: NpcRecord, player: Entity, delta: float) -> void:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.hazard_distress = NpcRouteService.danger_here(actor)
	awareness.light_distress = false
	_observe_retreat(actor, person, player, awareness, delta)
	for rule: DEF_NpcTrait in person.profile.rules:
		if rule.kind == DEF_NpcTrait.Kind.FIRE_AURA:
			_ensure_aura(actor, person, rule)
			continue
		var triggered: bool = false
		match rule.kind:
			DEF_NpcTrait.Kind.GAZE_AVERSION:
				triggered = awareness.player_visible and _gazing(player, actor, rule)
			DEF_NpcTrait.Kind.LIGHT_AVERSION:
				triggered = NpcLightingService.exposure_at(actor.global_position + Vector3.UP, [actor.get_rid()]) > rule.light_threshold
				awareness.light_distress = triggered
			DEF_NpcTrait.Kind.DARK_PREDATOR:
				triggered = awareness.player_visible and NpcLightingService.exposure_at((player as Node as Node3D).global_position + Vector3.UP, [(player as Node as PhysicsBody3D).get_rid()]) < rule.light_threshold
			DEF_NpcTrait.Kind.STRENGTH_TEST:
				triggered = awareness.player_visible and _looks_vulnerable(player, person)
		if not triggered:
			awareness.rule_exposure[rule.kind] = 0.0
			continue
		var exposure: float = awareness.rule_exposure.get(rule.kind, 0.0) + delta
		awareness.rule_exposure[rule.kind] = exposure
		if exposure >= rule.warning_seconds and not awareness.warned_rules.has(rule.kind):
			awareness.warned_rules.append(rule.kind)
			actor.show_message(rule.warning_text + " · " + rule.countermeasure)
			NpcPerceptionService.emit_noise(actor, actor.global_position, person.profile.hearing_range * 0.5)
		if exposure >= rule.warning_seconds + rule.reaction_seconds and not awareness.reacted_rules.has(rule.kind) and awareness.player_visible:
			awareness.reacted_rules.append(rule.kind)
			var cycle: C_DayCycle = DayPhaseService.current()
			var incident: StringName = StringName("rule/%s/%d/%d/%d" % [person.npc_id, cycle.day_index, cycle.phase, rule.kind])
			NpcSocialService.react(actor, player, NpcMemory.Kind.OFFENSE, incident)

## Finds a dark refuge without claiming another body's movement authority.
static func dark_refuge(actor: E_DistrictNpc, person: NpcRecord) -> Vector3:
	var district: C_District = DistrictPopulationService.current()
	var best: Vector3 = DistrictPopulationService.position_for(person.portal_id)
	var score: float = INF
	var rule: DEF_NpcTrait = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION)
	for place: DEF_DistrictPlace in district.definition.places:
		var point: Vector3 = DistrictPopulationService.position_for(place.key)
		var light: float = NpcLightingService.exposure_at(point + Vector3.UP, [actor.get_rid()])
		if light > rule.light_threshold:
			continue
		var distance: float = actor.global_position.distance_squared_to(point)
		if distance < score:
			score = distance
			best = point
	return best

static func _gazing(player: Entity, actor: E_DistrictNpc, rule: DEF_NpcTrait) -> bool:
	var spatial: Node3D = player as Node as Node3D
	if spatial == null or spatial.global_position.distance_to(actor.global_position) > rule.radius * 3.0:
		return false
	var camera: Camera3D = spatial.get_viewport().get_camera_3d()
	if camera == null:
		return false
	return -camera.global_basis.z.dot((actor.global_position + Vector3.UP * NpcPerceptionService.EYE_HEIGHT - camera.global_position).normalized()) >= rule.gaze_alignment

static func _looks_vulnerable(player: Entity, person: NpcRecord) -> bool:
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

static func _observe_retreat(actor: E_DistrictNpc, person: NpcRecord, player: Entity, awareness: C_NpcAwareness, delta: float) -> void:
	var player_body: RigidBody3D = player as Node as RigidBody3D
	if person.profile.personality != DEF_NpcProfile.Personality.BRAZEN or player_body == null or not awareness.player_visible or CombatService.target_for(actor) != player:
		awareness.retreat_elapsed = 0.0
		return

	var outward: Vector3 = player_body.global_position - actor.global_position
	outward.y = 0.0
	if player_body.linear_velocity.dot(outward.normalized()) < person.profile.retreat_speed:
		awareness.retreat_elapsed = 0.0
		return

	awareness.retreat_elapsed += delta
	if awareness.retreat_elapsed < person.profile.retreat_seconds:
		return

	var cycle: C_DayCycle = DayPhaseService.current()
	var incident: StringName = StringName("retreat/%s/%d/%d" % [person.npc_id, cycle.day_index, cycle.phase])
	NpcSocialService.react(actor, player, NpcMemory.Kind.SUBMISSION, incident)


static func _ensure_aura(actor: E_DistrictNpc, person: NpcRecord, rule: DEF_NpcTrait) -> void:
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
