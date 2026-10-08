extends RefCounted
## Диагностика и явные QA-запросы игровых сервисов; запись/загрузка используют отдельные debug_slots.
class_name DebugGameplayService

const SLOT_DIRECTORY: String = "user://debug_slots"
const MAX_SLOT_LENGTH: int = 32
const ITEM_DIRECTORY: String = "res://content/definitions/gameplay/inventory"
const CHALLENGE_DIRECTORY: String = "res://content/definitions/gameplay/challenges"
const MEAT_SCENE: PackedScene = preload("res://content/entities/inventory/npc_meat_pickup.tscn")
const MEAT_OFFSET: Vector3 = Vector3(0.0, 0.6, -1.0)


#region Авторские определения и цель
## Читает авторские .tres каталога с учётом export .remap; не создаёт новые определения.
static func definitions(directory: String) -> Array[GameDefinition]:
	var result: Array[GameDefinition] = []
	for filename: String in DirAccess.get_files_at(directory):
		var original: String = filename.trim_suffix(".remap")
		if not original.ends_with(".tres"): continue
		var definition: GameDefinition = load(directory.path_join(original)) as GameDefinition
		if definition != null and definition not in result: result.append(definition)
	return result


## Ищет авторский предмет по ключу в каталоге ресурсов, затем в Commerce; отсутствие даёт null.
static func item(key: String) -> DEF_InventoryItem:
	for definition: GameDefinition in definitions(ITEM_DIRECTORY):
		if String(definition.key) == key: return definition as DEF_InventoryItem
	var state: C_Commerce = CommerceService.current()
	if state != null:
		for definition: DEF_InventoryItem in state.catalog:
			if definition != null and String(definition.key) == key: return definition
	return null


## Разрешает QA-цель; для визита возвращает его действующего получателя, иначе Entity цели.
static func subject(raw: String) -> Entity:
	var target: DebugTarget = DebugTargetResolver.resolve(raw)
	return CustomerFlowService.customer_for(target.visit.visit_id) if target.visit != null else target.entity


#endregion

#region Диагностика состояния
## Возвращает строки указанной группы состояния; живые цели проверяются, новые игровые факты не создаются.
static func info(kind: String, raw: String = "self") -> DebugServiceResult:
	var entity: Entity = subject(raw)
	var lines: PackedStringArray = []
	if kind in ["stamina", "hunger", "inventory", "npc", "nav", "challenge", "hazard", "progress", "corpse"] and not EntityAvailability.contains(entity, ECS.world):
		return failure("Live target unavailable: %s" % raw)

	match kind:
		"stamina":
			var state: C_Stamina = entity.get_component(C_Stamina) as C_Stamina
			if state == null: return failure("Target has no stamina")
			lines.append("entity=%s reserve=%.2f/%.2f running=%s mode=%s weight_drain=%.2f recovery_seconds=%.2f exhausted=%s" % [entity.id, state.current, state.maximum, state.running, "toggle" if state.toggle_mode else "hold", state.drain_multiplier, state.recovery_remaining, state.exhausted])

		"hunger":
			var state: C_Hunger = entity.get_component(C_Hunger) as C_Hunger
			if state == null or state.policy == null: return failure("Target has no hunger policy")
			lines.append("entity=%s value=%.1f range=0..%.1f tier=%s speed_multiplier=%.2f damage_multiplier=%.2f" % [entity.id, state.value, state.policy.maximum, C_Hunger.Tier.keys()[HungerRules.tier(state)], HungerRules.speed_multiplier(state), HungerRules.damage_multiplier(state)])

		"inventory":
			var state: C_Inventory = entity.get_component(C_Inventory) as C_Inventory
			if state == null: return failure("Target has no inventory")
			var owned: Array[Entity] = InventoryService.items(entity)
			lines.append("entity=%s slots=%d/%d; slot indexing starts at 0" % [entity.id, owned.size(), state.maximum_stacks])
			for index: int in owned.size():
				var stack: C_InventoryItem = owned[index].get_component(C_InventoryItem) as C_InventoryItem
				lines.append("slot=%d id=%s key=%s quantity=%d" % [index, owned[index].id, stack.definition.key, stack.quantity])

		"trader":
			var trader: Entity = trader_for(raw)
			if trader == null: return failure("Live trader unavailable")
			var shop: C_Trader = trader.get_component(C_Trader) as C_Trader
			lines.append("entity=%s open=%s schedule=%s" % [trader.id, TraderCatalogRules.is_open(shop, DayPhaseService.current()), TraderCatalogRules.schedule_text(shop)])
			if shop.profile != null: lines.append("profile=%s courier=%s fee=%d delay_days=%d" % [shop.profile.key, shop.profile.home_delivery_enabled, shop.profile.delivery_fee, shop.profile.delivery_delay_days])
			for offer: DEF_InventoryItem in TraderCatalogRules.catalog(shop):
				if offer != null: lines.append("key=%s price=%d max_stack=%d kind=%s" % [offer.key, offer.market_price, offer.maximum_stack, DEF_InventoryItem.Kind.keys()[offer.kind]])

		"order":
			var state: C_Commerce = CommerceService.current()
			if state == null: return failure("Commerce unavailable")
			lines.append("receipts=%d pending=%d" % [state.receipts.size(), state.pending_deliveries.size()])
			for delivery: PendingDelivery in state.pending_deliveries:
				lines.append("id=%s item=%s quantity=%d due_day=%d fulfilled=%s" % [delivery.delivery_id, delivery.item.key, delivery.quantity, delivery.delivery_day, delivery.fulfilled])

		"quest":
			if not is_instance_valid(ECS.world): return failure("World unavailable")
			for owner: Entity in ECS.world.query.with_all([C_QuestSession]).execute():
				var state: C_QuestSession = owner.get_component(C_QuestSession) as C_QuestSession
				for record: RefusalQuestRecord in state.records:
					lines.append("quest=%s state=%s package=%s deadline_day=%d reward=%d paid=%s" % [record.quest_id, RefusalQuestRecord.State.keys()[record.state], record.package_id, record.deadline_day, record.reward, record.reward_paid])

		"npc":
			var state: C_NpcCombat = entity.get_component(C_NpcCombat) as C_NpcCombat
			if state == null: return failure("Target has no NPC attacks")
			var victim: Entity = CombatService.target_for(entity)
			lines.append("entity=%s phase=%s target=%s cooldown=%.2fs automatic=%s" % [entity.id, C_NpcCombat.Phase.keys()[state.phase], victim.id if victim != null else "none", state.cooldown_remaining, state.automatic_attack_selection])
			var agent: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
			if agent != null:
				var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
				lines.append("visit=%s phase=%s profile=%s" % [agent.visit_id, C_CustomerAgent.Phase.keys()[agent.phase], visit.definition.key if visit != null and visit.definition != null else &""])
			for kind_value: C_NpcCombat.Kind in [C_NpcCombat.Kind.MELEE, C_NpcCombat.Kind.RANGED]:
				for index: int in C_NpcCombat.MAX_VARIANTS:
					var ability: DEF_NpcAttack = NpcAttackService.variant_for(state, kind_value, index)
					if ability != null: lines.append("kind=%s slot=%d damage=%.1f range=%.1f..%.1fm animation=%s eligible=%s" % [C_NpcCombat.Kind.keys()[kind_value], index, ability.damage, ability.minimum_range, ability.maximum_range, ability.animation, NpcAttackService.can_start(entity, kind_value, index)])

		"nav":
			var npc: E_NpcCharacter = entity as E_NpcCharacter
			var state: C_NpcIntent = entity.get_component(C_NpcIntent) as C_NpcIntent
			if npc == null or npc.navigation_agent == null or state == null: return failure("Target has no NavigationAgent/intent")
			var navigation: NavigationAgent3D = npc.navigation_agent
			lines.append("entity=%s enabled=%s arrived=%s pending=%s blocked=%s distance=%.2fm avoidance=%s path_points=%d reachable=%s" % [entity.id, state.navigation_enabled, state.arrived, state.navigation_pending, state.navigation_blocked, state.distance_to_target, navigation.avoidance_enabled, navigation.get_current_navigation_path().size(), navigation.is_target_reachable()])

		"challenge":
			var state: C_Challenge = entity.get_component(C_Challenge) as C_Challenge
			if state == null or state.definition == null: return failure("Target has no challenge")
			lines.append("entity=%s definition=%s phase=%s result=%s elapsed=%.1fs timeout=%.1fs trigger=%s completion=%s departure=%s" % [entity.id, state.definition.key, C_Challenge.Phase.keys()[state.phase], ChallengeResult.Type.keys()[state.result], state.elapsed, state.definition.timeout_seconds, DEF_Challenge.Trigger.keys()[state.definition.trigger], DEF_Challenge.Completion.keys()[state.definition.completion], state.departure_requested])
			lines.append(state.definition.rule_text)
			lines.append("consumed=%s condition_violated=%s violation=%.2fs preparation=%.1fs" % [state.consumed, state.condition_violated, state.violation_elapsed, state.definition.preparation_seconds])

		"hazard":
			var state: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
			var lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
			if state == null or state.definition == null or lifetime == null: return failure("Target has no autonomous hazard")
			lines.append("entity=%s key=%s remaining=%.2fs persistent=%s awaiting=%s owner_loss_pending=%s ownership=%s owner_loss=%s origin=%s" % [entity.id, state.definition.key, lifetime.remaining_seconds, lifetime.persistent, lifetime.awaiting_resolution, lifetime.owner_loss_pending, DEF_Hazard.Ownership.keys()[state.definition.ownership], DEF_Hazard.OwnerLoss.keys()[state.definition.owner_loss], state.origin_id])

		"progress":
			var valve: E_InteractionTestValve = entity as E_InteractionTestValve
			if valve == null: return failure("Target does not expose valve progress")
			lines.append("entity=%s progress=%.3f active=%s mode=%s" % [entity.id, valve.get_progress(), valve.is_active(), E_InteractionTestValve.Mode.keys()[valve.mode]])

		"corpse":
			var state: C_NpcRemains = entity.get_component(C_NpcRemains) as C_NpcRemains
			if state == null: return failure("Target has no NPC remains contract; current prototype drops edible meat immediately on death")
			lines.append("entity=%s dead=%s released=%s; prototype drops edible pickups at death, no corpse hit counter" % [entity.id, entity.has_component(C_Death), state.released])

		_:
			return failure("Unknown information group")
	return success(lines if not lines.is_empty() else PackedStringArray(["none"]))


#endregion

#region Торговец и физический QA-дроп
## Явный живой торговец либо первый доступный при пустом выборе; погибший исключается.
static func trader_for(raw: String = "") -> Entity:
	if not is_instance_valid(ECS.world): return null
	if not raw.is_empty():
		var explicit: Entity = subject(raw)
		return explicit if EntityAvailability.contains(explicit, ECS.world) and explicit.has_component(C_Trader) and not explicit.has_component(C_Death) else null
	return ECS.world.query.with_all([C_Trader]).with_none([C_Death]).execute_one()


## Явно создаёт один физический мясной pickup рядом с доступным игроком; дальнейшее использование штатное.
static func meat_spawn() -> DebugServiceResult:
	var actor: Entity = DebugTargetResolver.player()
	var node: Node3D = actor as Node as Node3D
	if not GrabService.holder_available(actor) or node == null: return failure("Live physical player unavailable")
	var meat: Entity = MEAT_SCENE.instantiate() as Entity
	# Позиция задаётся однократно при создании; дальнейшее движение принадлежит физическому телу.
	var position: Vector3 = node.global_transform * MEAT_OFFSET
	node.get_parent().add_child(meat)
	(meat as Node as Node3D).global_position = position
	ECS.world.add_entity(meat, null, false)
	return success(PackedStringArray(["entity=%s; edible physical meat spawned" % meat.id]))


#endregion

#region Отдельные слоты сохранения
## Записывает/восстанавливает проверенный утренний snapshot в debug_slots при свободных действиях; обычный autosave не используется.
static func save_slot(slot: String, writing: bool) -> DebugServiceResult:
	var path: String = slot_path(slot)
	if path.is_empty(): return failure("Slot requires 1..32 ASCII letters/digits/_/-. No paths; gameplay autosave is never used")
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING or not is_instance_valid(ECS.world): return failure("Persistence testing requires Morning; existing save contract restores a Morning snapshot")
	if not ECS.world.query.with_all([C_CustomerAgent]).with_none([C_Death]).execute().is_empty(): return failure("Finish live visits before persistence testing")
	for actor: Entity in ECS.world.entities:
		var challenge: C_Challenge = actor.get_component(C_Challenge) as C_Challenge
		if InteractionControlFocus.current(actor) > InteractionControlFocus.Priority.HANDS or (challenge != null and challenge.phase in [C_Challenge.Phase.ARMED, C_Challenge.Phase.ACTIVE]): return failure("Finish captured interactions / close UI / finish challenges before persistence testing")
		for link: Relationship in actor.relationships:
			if link.relation is R_HeldBy or link.relation is R_ProlongedOn or link.relation is R_PushedBy or link.relation is R_CartDrivenBy: return failure("Release held objects / push / cart / active interactions before persistence testing")
	var root: Node = ECS.world.get_parent()
	if writing:
		var data: Dictionary = WorldSnapshotService.capture(root, cycle.day_index)
		if not WorldSnapshotService.valid(data, root): return failure("Snapshot is incompatible; slot not overwritten")
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(SLOT_DIRECTORY)
		if directory_error != OK: return failure("Cannot create isolated slot directory")
		var error: Error = AutosaveStore.write(data, path)
		return success(PackedStringArray(["path=%s morning_day=%d" % [path, cycle.day_index]])) if error == OK else failure("Write failed: %s" % error_string(error))

	var saved: Dictionary = AutosaveStore.read(path)
	if saved.is_empty() or not WorldSnapshotService.valid(saved, root): return failure("Isolated save missing/corrupt/incompatible; world unchanged")
	return success(PackedStringArray(["path=%s restored Morning; world state replaced" % path])) if WorldSnapshotService.restore(saved, root) else failure("Restore rejected")


## Путь отдельного слота для 1–32 ASCII букв/цифр/_/-; любые пути/прочие символы отклоняются пустой строкой.
static func slot_path(slot: String) -> String:
	if slot.is_empty() or slot.length() > MAX_SLOT_LENGTH: return ""
	for character: String in slot:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-": return ""
	return SLOT_DIRECTORY.path_join(slot + ".pvzh")


#endregion

#region Результат команды
## Создаёт принятый результат со строками контекста.
static func success(lines: PackedStringArray = []) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	result.success = true
	result.details = lines
	return result


## Создаёт отказ с пояснением без изменения мира.
static func failure(message: String) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	result.message = message
	return result

#endregion
