extends RefCounted
## Bounded motivated NPC conflicts and opportunistic physical loot using ordinary inventory rules.
class_name NpcCommunityService

#region Community activity
## Executes one free activity and reports whether it took the idle movement slot.
static func idle(actor: E_DistrictNpc, person: NpcRecord) -> bool:
	var district: C_District = DistrictPopulationService.current()
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	for item: Entity in InventoryService.items(actor):
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		if state.definition.kind == DEF_InventoryItem.Kind.FOOD and hunger.value >= district.definition.npc_food_threshold:
			InventoryService.use(actor, item)
			return true
	var loot: Entity = _loot_target(actor)
	if loot != null and _available_loot(loot, actor):
		var point: Vector3 = (loot as Node as Node3D).global_position
		if actor.global_position.distance_to(point) <= district.definition.loot_distance:
			InventoryService.transfer(loot, actor)
			_clear_loot(actor)
		else:
			NpcIntentArbiter.move_to(actor, point, district.definition.loot_distance, C_NpcDecision.Owner.IDLE)
		return true
	_clear_loot(actor)
	for item: Entity in ECS.world.query.with_all([C_InventoryItem]).execute():
		var spatial: Node3D = item as Node as Node3D
		if spatial == null or not _available_loot(item, actor) or actor.global_position.distance_to(spatial.global_position) > person.profile.vision_range:
			continue
		if not NpcPerceptionService.can_see_point(actor, spatial.global_position + Vector3.UP * 0.1, person.profile, item):
			continue
		actor.add_relationship(Relationship.new(R_NpcLootTarget.new(), item))
		return true
	return _conflict(actor, person)

## Releases the live pickup reservation when a higher priority interrupts free activity.
static func cancel_activity(actor: Entity) -> void:
	_clear_loot(actor)

## Spends the phase budget only for a motivated, perceived and affordable new attack.
static func begin_conflict(actor: E_DistrictNpc, person: NpcRecord, target: E_DistrictNpc) -> bool:
	var district: C_District = DistrictPopulationService.current()
	if not person.profile.initiates_conflicts or district.ambient_conflicts >= district.definition.ambient_conflicts_per_phase or CombatService.target_for(actor) != null:
		return false
	if target == null or target == actor or target.has_component(C_Death) or target.has_component(C_CustomerAgent) or not NpcPerceptionService.can_see(actor, target, person.profile):
		return false
	var hunger: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	var motive: bool = hunger.value >= district.definition.npc_attack_hunger
	for memory: NpcMemory in person.memories:
		if memory.actor_id == NpcSocialService.identity_for(target) and memory.kind == NpcMemory.Kind.ATTACK:
			motive = true
	var own_health: C_Health = actor.get_component(C_Health) as C_Health
	if not motive or own_health.current < own_health.value * person.profile.pursuit_health_reserve:
		return false
	var identity: C_NpcIdentity = target.get_component(C_NpcIdentity) as C_NpcIdentity
	var target_person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
	if target_person.profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null and DamageResistanceRules.effective(actor, 1.0, DamageRequest.Type.FIRE) > 0.0:
		return false
	if not CombatService.bind_target(actor, target):
		return false
	district.ambient_conflicts += 1
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.last_seen_position = target.global_position
	awareness.has_last_seen = true
	actor.show_message("Мне нужна добыча. Защищайся!")
	return true

static func _conflict(actor: E_DistrictNpc, person: NpcRecord) -> bool:
	if not person.profile.initiates_conflicts:
		return false
	for record: NpcRecord in DistrictPopulationService.current().people:
		if record.death_day == 0 and record.placement == NpcRecord.Placement.STREET:
			if begin_conflict(actor, person, DistrictPopulationService.body_for(record.npc_id)):
				return true
	return false

static func _available_loot(item: Entity, claimant: Entity) -> bool:
	if not EntityAvailability.contains(item, ECS.world) or item.has_component(C_Package) or InventoryService.owner_for(item) != null or GrabService.held_relationship(item) != null:
		return false
	for link: Relationship in item.relationships:
		if link.relation is R_AssignedTo or link.relation is R_StoredIn:
			return false
	for participant: Entity in ECS.world.query.with_relationship([Relationship.new(R_NpcLootTarget.new(), item)]).execute():
		if participant != claimant:
			return false
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	return state != null and state.definition != null and not state.transfer_in_progress and state.pending_use_id.is_empty()

static func _loot_target(actor: Entity) -> Entity:
	for link: Relationship in actor.relationships:
		if link.relation is R_NpcLootTarget:
			return link.target as Entity if EntityAvailability.contains(link.target, ECS.world) else null
	return null

static func _clear_loot(actor: Entity) -> void:
	for link: Relationship in actor.relationships.duplicate():
		if link.relation is R_NpcLootTarget:
			actor.remove_relationship(link)
#endregion
