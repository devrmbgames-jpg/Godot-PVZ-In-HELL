extends RefCounted
## Personal incident memory, deterministic reactions and perception-limited witnesses.
class_name NpcSocialService

#region Incidents and personality
## Applies semantic conversation choices without modifying parcel finance.
static func dialogue_response(body: E_DistrictNpc, actor: Entity, intent: CustomerDialogueIntent.Type, incident: StringName) -> NpcMemory.Reaction:
	var kind: NpcMemory.Kind = NpcMemory.Kind.HELP
	match intent:
		CustomerDialogueIntent.Type.THREAT:
			kind = NpcMemory.Kind.THREAT
		CustomerDialogueIntent.Type.LIE:
			kind = NpcMemory.Kind.LIE
		CustomerDialogueIntent.Type.JOKE:
			kind = NpcMemory.Kind.JOKE
	return react(body, actor, kind, incident)

## Returns a stable participant identity only at an already recognized interaction boundary.
static func identity_for(actor: Entity) -> StringName:
	if not is_instance_valid(actor):
		return &""
	if actor.has_component(C_PlayerInputController):
		return &"player"
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	return identity.npc_id if identity != null else &""

## Records a reaction once; returning to the same incident never rerolls it.
static func react(body: E_DistrictNpc, actor: Entity, kind: NpcMemory.Kind, incident: StringName) -> NpcMemory.Reaction:
	var person: NpcRecord = DistrictPopulationService.person_for(identity_for(body))
	if person == null or person.death_day != 0:
		return NpcMemory.Reaction.TALK
	for memory: NpcMemory in person.memories:
		if memory.incident_id == incident:
			return memory.reaction
	var reaction: NpcMemory.Reaction = _choose(person.profile, kind, hash(str(person.npc_id) + ":" + str(incident)))
	remember(person, actor, body, kind, incident, reaction)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	match reaction:
		NpcMemory.Reaction.ATTACK:
			if GrabService.holder_available(actor):
				CombatService.bind_target(body, actor)
				awareness.last_seen_position = (actor as Node as Node3D).global_position
				awareness.has_last_seen = true
				awareness.search_elapsed = 0.0
				ChallengeService.cancel(body)
				body.show_message("Я нападаю! Защищайся или уходи.")
		NpcMemory.Reaction.FLEE:
			awareness.fleeing = true
			if actor as Node as Node3D != null:
				awareness.last_seen_position = (actor as Node as Node3D).global_position
			body.show_message("Не трогай меня! Я ухожу.")
		NpcMemory.Reaction.RESPECT:
			body.show_message("Ладно. Вижу, ты умеешь постоять за себя.")
		NpcMemory.Reaction.ACCEPT:
			body.show_message("Ха! Договорились.")
		_:
			body.show_message("Поговорим спокойно. Без новых провокаций.")
	return reaction

## Records understood information without forcing a witness into combat.
static func remember(person: NpcRecord, actor: Entity, victim: Entity, kind: NpcMemory.Kind, incident: StringName, reaction: NpcMemory.Reaction = NpcMemory.Reaction.TALK) -> void:
	for previous: NpcMemory in person.memories:
		if previous.incident_id == incident:
			return
	var memory: NpcMemory = NpcMemory.new()
	memory.incident_id = incident
	memory.actor_id = identity_for(actor)
	memory.victim_id = identity_for(victim)
	memory.kind = kind
	var cycle: C_DayCycle = DayPhaseService.current()
	memory.day = cycle.day_index if cycle != null else 1
	memory.reaction = reaction
	person.memories.append(memory)

static func _choose(profile: DEF_NpcProfile, kind: NpcMemory.Kind, seed_value: int) -> NpcMemory.Reaction:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	var roll: float = random.randf()
	if kind in [NpcMemory.Kind.HELP, NpcMemory.Kind.BROKEN_PROMISE]:
		return NpcMemory.Reaction.ACCEPT if kind == NpcMemory.Kind.HELP else NpcMemory.Reaction.TALK
	if kind == NpcMemory.Kind.JOKE and profile.personality == DEF_NpcProfile.Personality.CHEERFUL:
		return NpcMemory.Reaction.ACCEPT if roll < profile.joke_acceptance_probability else NpcMemory.Reaction.TALK
	if profile.personality == DEF_NpcProfile.Personality.TIMID:
		if roll < profile.timid_flee_probability:
			return NpcMemory.Reaction.FLEE
		return NpcMemory.Reaction.ATTACK if roll < profile.timid_flee_probability + profile.timid_attack_probability else NpcMemory.Reaction.TALK
	if profile.personality == DEF_NpcProfile.Personality.BRAZEN and kind == NpcMemory.Kind.THREAT:
		return NpcMemory.Reaction.RESPECT if roll < profile.high_attack_probability else NpcMemory.Reaction.ATTACK
	if kind == NpcMemory.Kind.JOKE:
		return NpcMemory.Reaction.TALK
	if roll < profile.high_attack_probability:
		return NpcMemory.Reaction.ATTACK
	return NpcMemory.Reaction.FLEE if roll < profile.high_attack_probability + profile.low_flee_probability else NpcMemory.Reaction.TALK
#endregion

#region Committed violence
## Damage results are witnessed physically; unknown attackers produce noise, not omniscience.
static func observe_damage(result: DamageResult) -> void:
	if result == null or result.request == null or result.applied_amount <= 0.0 or result.request.operation != DamageRequest.Operation.DAMAGE:
		return
	var request: DamageRequest = result.request
	var victim: Entity = request.target
	var district: C_District = DistrictPopulationService.current()
	if district != null:
		NpcPerceptionService.emit_noise(victim, result.world_pose.origin, district.definition.damage_noise_radius)
	if request.combat_context == null:
		return
	var actor: Entity = request.instigator if is_instance_valid(request.instigator) else request.source
	if district == null or not is_instance_valid(victim):
		return
	if request.incident_id == &"":
		request.incident_id = StringName("violence/%d" % district.next_incident)
		district.next_incident += 1
	var kind: NpcMemory.Kind = NpcMemory.Kind.KILLING if result.outcome == DamageResult.Outcome.HEALTH_DEPLETED else NpcMemory.Kind.ATTACK
	for person: NpcRecord in district.people:
		if person.death_day != 0 or person.placement != NpcRecord.Placement.STREET:
			continue
		var observer: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if observer == null or observer.has_component(C_Death):
			continue
		var sees_actor: bool = NpcPerceptionService.can_see(observer, actor, person.profile)
		if observer == victim:
			if sees_actor:
				react(observer, actor, kind, request.incident_id)
			else:
				var awareness: C_NpcAwareness = observer.get_component(C_NpcAwareness) as C_NpcAwareness
				awareness.fleeing = true
		elif sees_actor and NpcPerceptionService.can_see(observer, victim, person.profile, true):
			remember(person, actor, victim, kind, request.incident_id)
#endregion
