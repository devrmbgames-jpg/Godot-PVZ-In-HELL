extends RefCounted
## Ограниченные мотивированные конфликты NPC и подбор доступной физической добычи.
class_name NpcCommunityService


#region Finite personal return reaction
## Только существующая idle ветка вызывает операцию; бой/опасность/роли имеют приоритет.
## True означает применённую разовую реакцию; caller больше не использует captured actor.
static func react_to_return(body: E_DistrictNpc, person: NpcRecord) -> bool:
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	if (
		person.death_day != 0 or body.has_active_role()
		or CombatQueries.target_for(body) != null or NpcDialogueService.participant(body) != null
		or awareness.fleeing or awareness.hazard_distress or awareness.light_distress
	):
		return false
	for episode: NpcDeathRecord in person.deaths:
		if (
			episode.returned_day == 0 or episode.reaction_applied
			or episode.known_actor_id.is_empty()
		):
			continue
		var player: bool = episode.known_actor_id == &"player"
		if player and not episode.response_given:
			continue
		var target: Entity = (
			ECS.world.query.with_all([C_PlayerInputController]).execute_one()
			if player else NpcPopulationQueries.body_for(episode.known_actor_id)
		)
		if (
			not GrabQueries.holder_available(target)
			or body.global_position.distance_to((target as Node as Node3D).global_position)
			> NpcPopulationQueries.current().definition.conversation_range
			or not NpcPerceptionService.can_see(body, target, person)
		):
			continue
		if not player and episode.reaction == NpcMemory.Reaction.ATTACK:
			if person.profile.initiates_conflicts:
				return NpcCommunityService.begin_conflict(body, person, target as E_DistrictNpc)
			# Существующий запрет инициативных конфликтов сохраняется; упрёк не начинает бой.
			episode.reaction_applied = true
			body.show_message("Я помню, как ты меня убил. Второго раза не хочу.")
			return true
		episode.reaction_applied = true
		var captured_world: World = ECS.world
		var body_reference: WeakRef = weakref(body)
		NpcSocialService.apply_reaction(body, target, episode.reaction)
		# Social facts may retire the speaker before its optional personal bark.
		var speaker: E_DistrictNpc = body_reference.get_ref() as E_DistrictNpc
		if (
			is_instance_valid(captured_world) and ECS.world == captured_world
			and EntityAvailability.contains(speaker, captured_world)
			and NpcPopulationQueries.person_for(person.npc_id) == person
		):
			speaker.show_message("Я вернулся. И я помню, кто меня убил.")
		return true
	return false

#endregion


#region Занятия сообщества
## При подходящем голоде запрашивает InventoryService.use для первой принадлежащей еды.
## True означает найденный предмет и вызов use; результат использования здесь не проверяется.
static func eat_inventory(actor: E_DistrictNpc) -> bool:
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	if (
		hunger == null
		or hunger.value < NpcPopulationQueries.current().definition.npc_food_threshold
	):
		return false
	for item: Entity in InventoryService.items(actor):
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		if state.definition.kind == DEF_InventoryItem.Kind.FOOD:
			InventoryService.use(actor, item)
			return true
	return false


## Возвращает только доступную добычу действующего Relationship.
static func loot_for(actor: Entity) -> Entity:
	var item: Entity = _loot_target(actor)
	return item if item != null and _available_loot(item, actor) else null


## Сначала освобождает прежний резерв, затем связывает первый воспринимаемый свободный предмет.
## False оставляет NPC без прежней добычи; частоту выбора задаёт BT.
static func choose_loot(actor: E_DistrictNpc, person: NpcRecord) -> bool:
	_clear_loot(actor)
	for item: Entity in ECS.world.query.with_all([C_InventoryItem]).execute():
		var spatial: Node3D = item as Node as Node3D
		if (
			spatial == null or not _available_loot(item, actor)
			or actor.global_position.distance_to(spatial.global_position)
			> person.profile.vision_range
		):
			continue
		if (
			not NpcPerceptionService.can_see_point(
				actor,
				spatial.global_position + Vector3.UP * 0.1,
				person,
				item,
			)
		):
			continue
		actor.add_relationship(Relationship.new(R_NpcLootTarget.new(), item))
		return true
	return false


## После физического приближения возвращает результат InventoryService.transfer.
## Собственный резерв освобождается и при отказе transfer; чужой резерв не отменяется.
static func collect_loot(actor: E_DistrictNpc) -> bool:
	var loot: Entity = loot_for(actor)
	if (
		loot == null
		or actor.global_position.distance_to((loot as Node as Node3D).global_position)
		> NpcPopulationQueries.current().definition.loot_distance
	):
		return false
	var loot_transferred: bool = InventoryService.transfer(loot, actor)
	_clear_loot(actor)
	return loot_transferred


## Снимает живое резервирование добычи при прерывании более важным действием.
static func cancel_activity(actor: Entity) -> void:
	_clear_loot(actor)


## Расходует лимит фазы только на новое мотивированное, воспринимаемое и допустимое по риску
## нападение.
static func begin_conflict(actor: E_DistrictNpc, person: NpcRecord, target: E_DistrictNpc) -> bool:
	var district: C_District = NpcPopulationQueries.current()
	if (
		not person.profile.initiates_conflicts
		or district.ambient_conflicts >= district.definition.ambient_conflicts_per_phase
		or CombatQueries.target_for(actor) != null
	):
		return false
	if (
		target == null or target == actor or target.has_component(C_Death)
		or target.has_active_role() or not NpcPerceptionService.can_see(actor, target, person)
	):
		return false

	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	var motive: bool = (
		hunger.value >= district.definition.npc_attack_hunger
		or NpcLifeRules.pending_conflict(person, NpcSocialService.identity_for(target))
	)
	for memory: NpcMemory in person.memories:
		if (
			memory.actor_id == NpcSocialService.identity_for(target)
			and memory.victim_id == person.npc_id and memory.kind == NpcMemory.Kind.ATTACK
		):
			motive = true
	var own_health: C_Health = actor.get_component(C_Health) as C_Health
	if not motive or own_health.current < own_health.value * person.profile.pursuit_health_reserve:
		return false

	var identity: C_NpcIdentity = target.get_component(C_NpcIdentity) as C_NpcIdentity
	var target_person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	if (
		target_person.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null
		and DamageResistanceRules.effective(actor, 1.0, DamageRequest.Type.FIRE) > 0.0
	):
		return false
	if NpcBloodQueries.calmed(actor):
		return false
	var death_motive: NpcDeathRecord = null
	for episode: NpcDeathRecord in person.deaths:
		if (
			episode.returned_day > 0 and not episode.reaction_applied
			and episode.known_actor_id == NpcSocialService.identity_for(target)
			and episode.reaction == NpcMemory.Reaction.ATTACK
		):
			death_motive = episode
			break
	# Relationship callbacks must not spend this personal motive a second time.
	if death_motive != null:
		death_motive.reaction_applied = true
	if not CombatService.bind_target(actor, target):
		if death_motive != null:
			death_motive.reaction_applied = false
		return false

	district.ambient_conflicts += 1
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.last_seen_position = target.global_position
	awareness.has_last_seen = true
	actor.show_message(
		"Ты меня убил. Я вернулся и помню об этом. Защищайся!"
		if death_motive != null else "Мне нужна добыча. Защищайся!"
	)
	return true


## Проверяет мотивированные цели малого населения; выбор нападения разрешает BT.
static func try_conflict(actor: E_DistrictNpc, person: NpcRecord) -> bool:
	if not person.profile.initiates_conflicts:
		return false

	for record: NpcRecord in NpcPopulationQueries.current().people:
		if record.death_day == 0 and record.placement == NpcRecord.Placement.STREET:
			if begin_conflict(actor, person, NpcPopulationQueries.body_for(record.npc_id)):
				return true
	return false


static func _available_loot(item: Entity, claimant: Entity) -> bool:
	if (
		not EntityAvailability.contains(item, ECS.world) or item.has_component(C_Package)
		or InventoryService.owner_for(item) != null or GrabQueries.held_relationship(item) != null
	):
		return false

	for link: Relationship in item.relationships:
		# Reserved parcels are already excluded by the required C_Package identity above.
		if link.relation is R_StoredIn:
			return false

	for participant: Entity in (ECS.world.query.with_relationship([
			Relationship.new(R_NpcLootTarget.new(), item)
		]).execute()):
		if participant != claimant:
			return false

	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	return (
		state != null and state.definition != null
		and not state.transfer_in_progress and state.pending_use_id.is_empty()
	)


static func _loot_target(actor: Entity) -> Entity:
	for link: Relationship in actor.relationships:
		if link.relation is R_NpcLootTarget:
			if EntityAvailability.contains(link.target, ECS.world):
				return link.target as Entity
			return null
	return null


static func _clear_loot(actor: Entity) -> void:
	for link: Relationship in actor.relationships.duplicate():
		if link.relation is R_NpcLootTarget:
			actor.remove_relationship(link)
#endregion
