extends RefCounted
## Личная память, фиксированные реакции и свидетели с ограниченным восприятием.
class_name NpcSocialService

#region Инциденты и характер
## Применяет смысл диалогового выбора, не изменяя расчёты посылки.
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

## Возвращает постоянный ID участника только на границе уже распознанного взаимодействия.
static func identity_for(actor: Entity) -> StringName:
	if not is_instance_valid(actor):
		return &""
	if actor.has_component(C_PlayerInputController):
		return &"player"

	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	return identity.npc_id if identity != null else &""

## Фиксирует реакцию один раз; повтор инцидента не перебрасывает результат.
static func react(body: E_DistrictNpc, actor: Entity, kind: NpcMemory.Kind, incident: StringName) -> NpcMemory.Reaction:
	var person: NpcRecord = DistrictPopulationService.person_for(identity_for(body))
	if person == null or person.death_day != 0:
		return NpcMemory.Reaction.TALK

	for memory: NpcMemory in person.memories:
		if memory.incident_id == incident:
			return memory.reaction

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	var health: C_Health = body.get_component(C_Health) as C_Health
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger if is_instance_valid(actor) else null
	var predatory_player: bool = awareness.player_visible and is_instance_valid(actor) and actor.has_component(C_PlayerInputController) and HungerService.sees_npcs_as_food(hunger)
	var can_retreat: bool = predatory_player or health.current < health.value * person.profile.pursuit_health_reserve
	var reaction: NpcMemory.Reaction = _choose(person.profile, kind, hash(str(person.npc_id) + ":" + str(incident)), can_retreat)
	remember(person, actor, body, kind, incident, reaction)
	_apply_reaction(body, actor, reaction)
	return reaction

static func _apply_reaction(body: E_DistrictNpc, actor: Entity, reaction: NpcMemory.Reaction) -> void:
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
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent != null:
		var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
		if visit != null:
			visit.aggressive = reaction == NpcMemory.Reaction.ATTACK and CombatService.target_for(body) != null

## Запоминает распознанные сведения, не заставляя свидетеля вступать в бой.
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

## Запоминает срыв личного обещания и выбирает характерную реакцию без ночного физического боя.
static func remember_promise(person: NpcRecord, actor: Entity, body: E_DistrictNpc, incident: StringName) -> void:
	for previous: NpcMemory in person.memories:
		if previous.incident_id == incident:
			return

	var reaction: NpcMemory.Reaction = _choose(person.profile, NpcMemory.Kind.BROKEN_PROMISE, hash(str(person.npc_id) + ":" + str(incident)))
	remember(person, actor, body, NpcMemory.Kind.BROKEN_PROMISE, incident, reaction)
	# Обещание принято игроком даже в тестовой сессии, где его физическое тело отсутствует.
	person.memories.back().actor_id = &"player"

## Житель после сорванного обещания больше не предлагает игроку случайную личную подработку.
static func distrusts_player(person: NpcRecord) -> bool:
	for memory: NpcMemory in person.memories:
		if memory.actor_id == &"player" and memory.kind == NpcMemory.Kind.BROKEN_PROMISE:
			var job: NpcHomeDelivery = NpcDeliveryOfferService.find(memory.incident_id)
			if job != null and job.source == NpcHomeDelivery.Source.PERSONAL:
				return true
	return false

## Находит ещё не применённую личную реакцию, независимо от нового заказа NPC.
static func pending_promise(body: E_DistrictNpc) -> NpcHomeDelivery:
	var district: C_District = DistrictPopulationService.current()
	if body == null or district == null:
		return null
	var npc_id: StringName = identity_for(body)
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.npc_id == npc_id and job.source == NpcHomeDelivery.Source.PERSONAL and job.status == NpcHomeDelivery.Status.FAILED and not job.promise_reaction_applied:
			return job
	return null

## Применяет сохранённую реакцию при распознанном разговоре; повтор и загрузка не перебрасывают её.
static func resolve_promise(body: E_DistrictNpc, actor: Entity) -> bool:
	var job: NpcHomeDelivery = pending_promise(body)
	var person: NpcRecord = DistrictPopulationService.person_for(identity_for(body))
	if job == null or person == null or person.death_day != 0 or NpcDialogueService.participant(body) != actor:
		return false

	for memory: NpcMemory in person.memories:
		if memory.incident_id != job.job_id:
			continue

		job.promise_reaction_applied = true
		NpcDialogueService.close_for(body)
		_apply_reaction(body, actor, memory.reaction)
		if memory.reaction == NpcMemory.Reaction.TALK:
			body.show_message("Я запомнил твоё обещание. Больше личных доставок тебе не доверю.")
		return true
	return false

static func _choose(profile: DEF_NpcProfile, kind: NpcMemory.Kind, seed_value: int, can_retreat: bool = false) -> NpcMemory.Reaction:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	var roll: float = random.randf()
	if kind == NpcMemory.Kind.HELP:
		return NpcMemory.Reaction.ACCEPT
	if kind == NpcMemory.Kind.SUBMISSION:
		if profile.personality == DEF_NpcProfile.Personality.BRAZEN and roll < profile.high_attack_probability:
			return NpcMemory.Reaction.ATTACK
		return NpcMemory.Reaction.TALK
	if kind == NpcMemory.Kind.JOKE and profile.personality == DEF_NpcProfile.Personality.CHEERFUL:
		return NpcMemory.Reaction.ACCEPT if roll < profile.joke_acceptance_probability else NpcMemory.Reaction.TALK
	if profile.personality == DEF_NpcProfile.Personality.TIMID and kind != NpcMemory.Kind.JOKE:
		if roll < profile.timid_flee_probability:
			return NpcMemory.Reaction.FLEE
		return NpcMemory.Reaction.ATTACK if roll < profile.timid_flee_probability + profile.timid_attack_probability else NpcMemory.Reaction.TALK
	if profile.personality == DEF_NpcProfile.Personality.BRAZEN and kind == NpcMemory.Kind.THREAT:
		return NpcMemory.Reaction.RESPECT if roll < profile.high_attack_probability else NpcMemory.Reaction.ATTACK
	if kind == NpcMemory.Kind.JOKE:
		return NpcMemory.Reaction.TALK
	if roll < profile.high_attack_probability:
		return NpcMemory.Reaction.ATTACK
	var fleeing_allowed: bool = profile.personality != DEF_NpcProfile.Personality.AGGRESSIVE or can_retreat
	return NpcMemory.Reaction.FLEE if fleeing_allowed and roll < profile.high_attack_probability + profile.low_flee_probability else NpcMemory.Reaction.TALK
#endregion

#region Подтверждённое насилие
## Свидетели воспринимают урон; неизвестный атакующий создаёт шум без раскрытия личности.
static func observe_damage(result: DamageResult) -> void:
	if result == null or result.request == null or result.applied_amount <= 0.0 or result.request.operation != DamageRequest.Operation.DAMAGE:
		return

	var request: DamageRequest = result.request
	var victim: Entity = request.target
	var district: C_District = DistrictPopulationService.current()
	if district != null:
		# Боль от окружения слышна, но не зовёт соседей (и владельца огненной ауры) внутрь опасности.
		NpcPerceptionService.emit_noise(victim, result.world_pose.origin, district.definition.damage_noise_radius, request.combat_context != null)
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
