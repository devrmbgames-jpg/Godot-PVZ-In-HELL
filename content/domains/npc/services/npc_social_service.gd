extends RefCounted
## Личная память, фиксированные реакции и свидетели с ограниченным восприятием.
class_name NpcSocialService


#region Инциденты и характер
## Возвращает постоянный ID участника только на границе уже распознанного взаимодействия.
static func identity_for(actor: Entity) -> StringName:
	if not is_instance_valid(actor):
		return &""
	if actor.has_component(C_PlayerInputController):
		return &"player"

	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	return identity.npc_id if identity != null else &""


## Фиксирует реакцию один раз; повтор инцидента не перебрасывает результат.
static func react(
	body: E_DistrictNpc,
	actor: Entity,
	kind: NpcMemory.Kind,
	incident: StringName,
) -> NpcMemory.Reaction:
	var person: NpcRecord = NpcPopulationQueries.person_for(identity_for(body))
	if person == null or person.death_day != 0:
		return NpcMemory.Reaction.TALK

	for memory: NpcMemory in person.memories:
		if memory.incident_id == incident:
			return memory.reaction

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	var health: C_Health = body.get_component(C_Health) as C_Health
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger if is_instance_valid(actor) else null
	var predatory_player: bool = (
		awareness.player_visible and is_instance_valid(actor)
		and actor.has_component(C_PlayerInputController) and HungerRules.sees_npcs_as_food(hunger)
	)
	var can_retreat: bool = (
		predatory_player or health.current < health.value * person.profile.pursuit_health_reserve
	)
	var roll: float = GameTimeQueries \
			.decision(String(person.npc_id), DayPhaseQueries.current().day_index, "npc/social/%d/%s"
	% [kind, incident]) \
			.randf()
	var reaction: NpcMemory.Reaction = _choose(person.profile, kind, roll, can_retreat)
	remember(person, actor, body, kind, incident, reaction)
	apply_reaction(body, actor, reaction)
	return reaction


## Применяет зафиксированную реакцию и публикует результат для владельцев необязательных ролей.
static func apply_reaction(
	body: E_DistrictNpc,
	actor: Entity,
	reaction: NpcMemory.Reaction,
) -> void:
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	match reaction:
		NpcMemory.Reaction.ATTACK:
			if GrabQueries.holder_available(actor):
				CombatService.bind_target(body, actor)
				awareness.last_seen_position = (actor as Node as Node3D).global_position
				awareness.has_last_seen = true
				awareness.search_elapsed = 0.0
				ChallengeService.cancel(body)
				body.show_message("Я нападаю! Защищайся или уходи.")
		NpcMemory.Reaction.FLEE:
			CombatService.end_combat(body)
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
	var fact: NpcSocialReactionCommitted = NpcSocialReactionCommitted.new(
		reaction,
		CombatQueries.target_for(body) != null,
	)
	NpcDecisionService.request_wake(
		body,
		&"social_reaction",
		reaction in [NpcMemory.Reaction.ATTACK, NpcMemory.Reaction.FLEE],
	)
	ECS.world.emit_event(NpcSocialReactionCommitted.EVENT, body, fact)


## Запоминает распознанные сведения, не заставляя свидетеля вступать в бой.
static func remember(
	person: NpcRecord,
	actor: Entity,
	victim: Entity,
	kind: NpcMemory.Kind,
	incident: StringName,
	reaction: NpcMemory.Reaction = NpcMemory.Reaction.TALK,
) -> void:
	for previous: NpcMemory in person.memories:
		if previous.incident_id == incident:
			return

	var memory: NpcMemory = NpcMemory.new()
	memory.incident_id = incident
	memory.actor_id = identity_for(actor)
	memory.victim_id = identity_for(victim)
	memory.kind = kind
	var cycle: C_DayCycle = DayPhaseQueries.current()
	memory.day = cycle.day_index if cycle != null else 1
	memory.reaction = reaction
	person.memories.append(memory)


## Запоминает срыв личного обещания и выбирает характерную реакцию без ночного физического боя.
static func remember_promise(
	person: NpcRecord,
	actor: Entity,
	body: E_DistrictNpc,
	incident: StringName,
) -> void:
	for previous: NpcMemory in person.memories:
		if previous.incident_id == incident:
			return

	var roll: float = GameTimeQueries \
			.decision(String(person.npc_id), DayPhaseQueries.current().day_index, "npc/social/%d/%s"
	% [NpcMemory.Kind.BROKEN_PROMISE, incident]) \
			.randf()
	var reaction: NpcMemory.Reaction = _choose(person.profile, NpcMemory.Kind.BROKEN_PROMISE, roll)
	remember(person, actor, body, NpcMemory.Kind.BROKEN_PROMISE, incident, reaction)
	# Обещание принято игроком даже в тестовой сессии, где его физическое тело отсутствует.
	person.memories.back().actor_id = &"player"


## Житель после сорванного обещания больше не предлагает игроку случайную личную подработку.
static func distrusts_player(person: NpcRecord) -> bool:
	for memory: NpcMemory in person.memories:
		if memory.actor_id == &"player" and memory.kind == NpcMemory.Kind.BROKEN_PROMISE:
			for job: NpcHomeDelivery in NpcPopulationQueries.current().home_deliveries:
				if (
					job.job_id == memory.incident_id
					and job.source == NpcHomeDelivery.Source.PERSONAL
				):
					return true
	return false


static func _choose(
	profile: DEF_NpcProfile,
	kind: NpcMemory.Kind,
	roll: float,
	can_retreat: bool = false,
) -> NpcMemory.Reaction:
	if kind == NpcMemory.Kind.HELP:
		return NpcMemory.Reaction.ACCEPT
	if kind == NpcMemory.Kind.SUBMISSION:
		if (
			profile.personality == DEF_NpcProfile.Personality.BRAZEN
			and roll < profile.high_attack_probability
		):
			return NpcMemory.Reaction.ATTACK
		return NpcMemory.Reaction.TALK
	if kind == NpcMemory.Kind.JOKE and profile.personality == DEF_NpcProfile.Personality.CHEERFUL:
		return (
			NpcMemory.Reaction.ACCEPT
			if roll < profile.joke_acceptance_probability
			else NpcMemory \
					.Reaction \
					.TALK
		)
	if profile.personality == DEF_NpcProfile.Personality.TIMID and kind != NpcMemory.Kind.JOKE:
		if roll < profile.timid_flee_probability:
			return NpcMemory.Reaction.FLEE
		return (
			NpcMemory.Reaction.ATTACK
			if roll < profile.timid_flee_probability + profile.timid_attack_probability
			else NpcMemory \
					.Reaction \
					.TALK
		)
	if profile.personality == DEF_NpcProfile.Personality.BRAZEN and kind == NpcMemory.Kind.THREAT:
		return (
			NpcMemory.Reaction.RESPECT
			if roll < profile.high_attack_probability
			else NpcMemory \
					.Reaction \
					.ATTACK
		)
	if kind == NpcMemory.Kind.JOKE:
		return NpcMemory.Reaction.TALK
	if roll < profile.high_attack_probability:
		return NpcMemory.Reaction.ATTACK
	var fleeing_allowed: bool = (
		profile.personality != DEF_NpcProfile.Personality.AGGRESSIVE or can_retreat
	)
	return (
		NpcMemory.Reaction.FLEE
		if (
			fleeing_allowed
			and roll < profile.high_attack_probability + profile.low_flee_probability
		)
		else NpcMemory.Reaction.TALK
	)
#endregion


#region Подтверждённое насилие
## Свидетели воспринимают урон; неизвестный атакующий создаёт шум без раскрытия личности.
static func observe_damage(result: DamageResult) -> void:
	if (
		result == null or result.request == null or result.applied_amount <= 0.0
		or result.request.operation != DamageRequest.Operation.DAMAGE
	):
		return

	var request: DamageRequest = result.request
	var victim: Entity = request.target
	var district: C_District = NpcPopulationQueries.current()
	if district != null:
		# Боль от окружения слышна, но не зовёт соседей (и владельца огненной ауры) внутрь опасности.
		NpcPerceptionService.emit_noise(
			victim,
			result.world_pose.origin,
			district.definition.damage_noise_radius,
			request.combat_context != null,
		)
	if request.combat_context == null:
		return

	var actor: Entity = request.instigator if is_instance_valid(request.instigator) else request.source
	if district == null or not is_instance_valid(victim):
		return
	if request.incident_id == &"":
		request.incident_id = StringName("violence/%d" % district.next_incident)
		district.next_incident += 1
	var kind: NpcMemory.Kind = (
		NpcMemory.Kind.KILLING
		if result.outcome
		== DamageResult \
				.Outcome \
				.HEALTH_DEPLETED
		else NpcMemory.Kind.ATTACK
	)
	for person: NpcRecord in district.people:
		if person.death_day != 0 or person.placement != NpcRecord.Placement.STREET:
			continue

		var observer: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
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
