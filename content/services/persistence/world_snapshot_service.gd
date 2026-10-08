extends RefCounted
## Снимок постоянного мира; restore — явная однократная граница синхронизации тел и связей.
class_name WorldSnapshotService

const _ENTITY_SCENE_ROOTS: Array[String] = [
	"res://content/entities/",
	"res://content/domains/npc/entities/",
	"res://content/domains/customers/entities/",
	"res://content/domains/interaction/entities/",
	"res://content/domains/combat/entities/",
	"res://content/domains/motion/entities/",
]



#region Ключи и снимок
## Снимает постоянные сущности, включая отключённых NPC; копия цикла всегда задаёт указанное утро.
static func capture(root: Node, morning_day: int) -> Dictionary:
	if not is_instance_valid(ECS.world) or root == null or morning_day < 1:
		return {}

	var records: Array[Dictionary] = []
	for entity: Entity in ECS.world.entities:
		if not is_instance_valid(entity) or not _persistent(entity):
			continue

		var components: Array[Dictionary] = []
		for component: Component in entity.components.values():
			var data: Dictionary = SaveDataCodec.component_data(component)
			if data.is_empty():
				continue
			if component is C_DayCycle:
				(data.fields as Dictionary).day_index = morning_day
				(data.fields as Dictionary).phase = C_DayCycle.Phase.MORNING
			components.append(data)
		var links: Array[Dictionary] = []
		for binding: Relationship in entity.relationships:
			var kind: String = SnapshotLinks.OWNED if binding.relation is R_OwnedBy else SnapshotLinks.STORED if binding.relation is R_StoredIn else SnapshotLinks.CARGO if binding.relation is R_CartCargo else ""
			var target: Entity = binding.target as Entity
			if not kind.is_empty() and is_instance_valid(target):
				var link: Dictionary = {"kind": kind, "target": ActorIdentityRules.key_for(target, root)}
				if binding.relation is R_CartCargo:
					link.local_pose = (binding.relation as R_CartCargo).local_pose
				links.append(link)

		var node: Node3D = entity as Node as Node3D
		var record: Dictionary = {"key": ActorIdentityRules.key_for(entity, root), "entity_id": entity.id, "scene": entity.scene_file_path, "authored_id": PlacedIdentityRules.component_for(entity).actor_key() if PlacedIdentityRules.is_authored(entity, root) else "", "enabled": entity.enabled, "components": components, "links": links, "death": entity.has_component(C_Death)}
		if node != null:
			record.pose = node.global_transform
		record.completed_actions = PersistentInteractionState.completed(entity)
		var hazard_refs: Dictionary = PersistentHazardState.capture(entity, root)
		if not hazard_refs.is_empty():
			record.hazard_refs = hazard_refs
		var marks: C_PackageMarks = entity.get_component(C_PackageMarks) as C_PackageMarks
		if marks != null:
			var strokes: Array[Dictionary] = []
			for stroke: PackageMarkStroke in marks.strokes:
				strokes.append({"points": stroke.points, "normal": stroke.normal, "width": stroke.width, "color": stroke.color})
			record.ink = strokes
		var anchored: C_PlayerAnchored = entity.get_component(C_PlayerAnchored) as C_PlayerAnchored
		if anchored != null and anchored.snapshot != null:
			var original: AnchoredBodySnapshot = anchored.snapshot
			record.anchor = {"freeze": original.freeze, "freeze_mode": original.freeze_mode, "can_sleep": original.can_sleep}
		records.append(record)
	return {"version": AutosaveStore.SCHEMA_VERSION, "morning_day": morning_day, "entities": records}


#endregion

#region Предварительная проверка
## Проверяет весь снимок и закрытые контракты до изменения живого мира.
static func valid(data: Dictionary, root: Node) -> bool:
	if data.get("version") != AutosaveStore.SCHEMA_VERSION or not data.get("morning_day") is int or int(data.morning_day) < 1 or not data.get("entities") is Array:
		return false

	var keys: Dictionary = {}
	var ids: Dictionary[String, bool] = {}
	var authored_ids: Dictionary[String, bool] = {}
	var placed: Dictionary[String, Entity] = PlacedIdentityRules.resolver(root)
	if placed.size() != PlacedIdentityRules.authored_actors(root).size():
		return false
	var authored_entities: Array[Entity] = []
	var records: Dictionary[String, Dictionary] = {}
	var all_components: Dictionary[String, Dictionary] = {}
	var session_count: int = 0
	for value: Variant in data.entities:
		if not value is Dictionary:
			return false

		var record: Dictionary = value as Dictionary
		if not record.get("authored_id") is String or not record.get("scene") is String:
			return false
		if not record.get("key") is String or not record.get("entity_id") is String or String(record.entity_id).is_empty() or String(record.key).is_empty() or keys.has(record.key) or not record.get("components") is Array or not record.get("links") is Array or not record.get("enabled") is bool or not record.get("death") is bool:
			return false

		keys[record.key] = true
		if ids.has(String(record.entity_id)):
			return false

		ids[String(record.entity_id)] = true
		records[String(record.key)] = record
		var authored: String = String(record.get("authored_id", ""))
		var scene: String = String(record.get("scene", ""))
		if not authored.is_empty():
			if authored_ids.has(authored):
				return false

			authored_ids[authored] = true
		if not authored.is_empty():
			var target: Entity = placed.get(authored) as Entity
			if target == null or not root.is_ancestor_of(target) or target in authored_entities:
				return false

			authored_entities.append(target)
		if authored.is_empty() and not scene.is_empty() and (not _entity_scene_path_allowed(scene) or not ResourceLoader.exists(scene, "PackedScene")):
			return false
		if record.has("pose") and (not record.pose is Transform3D or not (record.pose as Transform3D).is_finite()):
			return false

		var types: Dictionary = {}
		for component_value: Variant in record.components:
			if not component_value is Dictionary:
				return false

			var component: Dictionary = component_value as Dictionary
			var script: Script = SaveDataCodec.component_script(String(component.get("type", "")))
			if script == null or types.has(script) or not component.get("fields") is Dictionary:
				return false

			var probe: Component = script.new() as Component
			if not SaveDataCodec.complete_component_data(script, component.fields as Dictionary):
				return false
			if not SaveDataCodec.apply_fields(probe, component.fields as Dictionary):
				return false

			types[script] = probe
			if probe is C_QuestSession and not RefusalQuestValidator.session_issues(probe as C_QuestSession).is_empty():
				return false
			if probe is C_DayCycle:
				session_count += 1
				if (probe as C_DayCycle).day_index != int(data.morning_day) or (probe as C_DayCycle).phase != C_DayCycle.Phase.MORNING:
					return false
			if probe is C_Wallet and ((probe as C_Wallet).balance < -WalletService.MAX_AMOUNT or (probe as C_Wallet).balance > WalletService.MAX_AMOUNT):
				return false
			if probe is C_InventoryItem and ((probe as C_InventoryItem).definition == null or (probe as C_InventoryItem).quantity < 1 or (probe as C_InventoryItem).quantity > (probe as C_InventoryItem).definition.maximum_stack):
				return false
			if probe is C_Package:
				var package: C_Package = probe as C_Package
				if package.definition == null or package.package_id.is_empty() or String(record.key) != "package/" + package.package_id:
					return false
			if probe is C_Health and (not is_finite((probe as C_Health).value) or (probe as C_Health).value <= 0.0 or not is_finite((probe as C_Health).current) or (probe as C_Health).current < 0.0 or (probe as C_Health).current > (probe as C_Health).value):
				return false
			if probe is C_Hunger and (not is_finite((probe as C_Hunger).value) or (probe as C_Hunger).value < 0.0):
				return false
			if probe is C_Stamina and (not is_finite((probe as C_Stamina).current) or (probe as C_Stamina).current < 0.0):
				return false

		all_components[String(record.key)] = types
		if types.has(C_PersistentIdentity):
			if String(record.key) != (types[C_PersistentIdentity] as C_PersistentIdentity).key:
				return false
		elif not types.has(C_Package):
			var expected_key: String = authored if not authored.is_empty() else "runtime/" + String(record.entity_id)
			if String(record.key) != expected_key:
				return false

		if record.has("ink"):
			if not record.ink is Array:
				return false

			for stroke: Variant in record.ink:
				if not stroke is Dictionary or not stroke.get("points") is PackedVector3Array or not stroke.get("normal") is Vector3 or not stroke.get("width") is float or not stroke.get("color") is Color:
					return false
		if record.has("anchor") and (not record.anchor is Dictionary or not (record.anchor as Dictionary).get("freeze") is bool or not (record.anchor as Dictionary).get("freeze_mode") is int or not (record.anchor as Dictionary).get("can_sleep") is bool):
			return false

	for record: Dictionary in data.entities:
		if record.has("hazard_refs") and (not record.hazard_refs is Dictionary or not all_components[String(record.key)].has(C_Hazard) or not PersistentHazardState.valid(record.hazard_refs as Dictionary, records)):
			return false

		for link: Variant in record.links:
			if not link is Dictionary or link.get("kind") not in [SnapshotLinks.OWNED, SnapshotLinks.STORED, SnapshotLinks.CARGO] or not keys.has(link.get("target")):
				return false
			if link.kind == SnapshotLinks.CARGO and not link.get("local_pose") is Transform3D:
				return false
	return session_count == 1 and SnapshotGraphRules.valid(records, all_components) and DistrictSnapshotRules.valid(records, all_components, int(data.morning_day)) and LootSnapshotRules.valid(records, all_components)


## Проверяет роли и prefab-контракты без регистрации Entities и без изменения живого World.
static func can_restore(data: Dictionary, root: Node) -> bool:
	if not valid(data, root):
		return false

	var placed: Dictionary[String, Entity] = PlacedIdentityRules.resolver(root)
	var entities: Dictionary[String, Entity] = {}
	var temporary: Array[Entity] = []

	for record: Dictionary in data.entities:
		var entity: Entity = placed.get(String(record.authored_id)) as Entity
		if entity == null:
			var scene: String = String(record.scene)
			var packed: PackedScene = load(scene) as PackedScene if not scene.is_empty() else null
			var instance: Node = packed.instantiate() if packed != null else Entity.new()
			entity = instance as Entity
			if entity == null:
				instance.free()
				for candidate: Entity in temporary:
					candidate.free()
				return false

			temporary.append(entity)
		entities[String(record.key)] = entity
	var compatible: bool = SnapshotGraphRules.valid_entities(data.entities as Array, entities)
	for candidate: Entity in temporary:
		candidate.free()
	return compatible


#endregion

#region Восстановление мира
## После полной проверки восстанавливает данные, позы и связи, затем отключение и участие района.
static func restore(data: Dictionary, root: Node) -> bool:
	if not can_restore(data, root):
		return false

	var placed: Dictionary[String, Entity] = PlacedIdentityRules.resolver(root)
	var entities: Dictionary[String, Entity] = {}
	var fresh: Array[Entity] = []
	# Подготовить все отсутствующие prefab до изменения живых сущностей.

	for record: Dictionary in data.entities:
		var entity: Entity = placed.get(String(record.authored_id)) as Entity
		if entity == null:
			for existing: Entity in ECS.world.entities:
				if is_instance_valid(existing) and ActorIdentityRules.key_for(existing, root) == String(record.key):
					entity = existing
					break
		if entity == null:
			var scene: String = String(record.scene)
			var packed: PackedScene = load(scene) as PackedScene if not scene.is_empty() else null
			var instance: Node = packed.instantiate() if packed != null else Entity.new()
			entity = instance as Entity
			if entity == null:
				instance.free()
				for candidate: Entity in fresh:
					candidate.free()
				return false

			fresh.append(entity)
		if entity in entities.values():
			for candidate: Entity in fresh:
				candidate.free()
			return false

		entities[String(record.key)] = entity
	if not SnapshotGraphRules.valid_entities(data.entities as Array, entities) or not _valid_ids(data.entities as Array, entities):
		for candidate: Entity in fresh:
			candidate.free()
		return false

	var activity: Dictionary[Observer, bool] = SnapshotRestoreBoundary.begin(ECS.world)

	for existing: Entity in ECS.world.entities.duplicate():
		if not is_instance_valid(existing) or not _persistent(existing):
			continue
		if existing not in entities.values() and not entities.has(ActorIdentityRules.key_for(existing, root)) and (existing.owner == null or (existing as Node) is RigidBody3D):
			ECS.world.remove_entity(existing)
	# Entity.id — источник истины; производный реестр GECS обновляется на этой границе.
	for entity: Entity in entities.values():
		if entity not in fresh:
			ECS.world.entity_id_registry.erase(entity.id)

	for record: Dictionary in data.entities:
		var entity: Entity = entities[String(record.key)]
		entity.id = String(record.entity_id)
		if entity not in fresh:
			ECS.world.entity_id_registry[entity.id] = entity
	# Удалить старое владение до восстановления поз и сохранённых связей.
	for entity: Entity in entities.values():
		OpenableService.cancel_player_request(entity)
		if entity not in fresh and not entity.enabled:
			ECS.world.enable_entity(entity)
		# Заменить владение с той же защитой, которую использует перенос инвентаря.
		# Слот и тележка выполняют обычное отсоединение перед новой привязкой.
		var item_state: C_InventoryItem = entity.get_component(C_InventoryItem) as C_InventoryItem
		if item_state != null:
			item_state.transfer_in_progress = true
		for existing: Relationship in entity.relationships.duplicate():
			if existing.relation is R_OwnedBy:
				entity.remove_relationship(existing)
			elif existing.relation is R_StoredIn:
				entity.remove_relationship(existing)
				PhysicalSlotService.detach(entity, existing)
			elif existing.relation is R_CartCargo:
				entity.remove_relationship(existing)
				CartCargoService.cargo_removed(entity, existing)
		if item_state != null:
			item_state.transfer_in_progress = false
		var old_anchor: C_PlayerAnchored = entity.get_component(C_PlayerAnchored) as C_PlayerAnchored
		var old_body: RigidBody3D = entity as Node as RigidBody3D
		if old_anchor != null and old_anchor.snapshot != null and old_body != null:
			old_body.freeze = old_anchor.snapshot.freeze
			old_body.freeze_mode = old_anchor.snapshot.freeze_mode
			old_body.can_sleep = old_anchor.snapshot.can_sleep
			entity.remove_component(old_anchor)

	for record: Dictionary in data.entities:
		var entity: Entity = entities[String(record.key)]
		if entity in fresh:
			if entity is E_Package:
				for component: Dictionary in record.components:
					if SaveDataCodec.component_script(String(component.type)) == C_Package:
						var definition: DEF_Package = SaveDataCodec.decode((component.fields as Dictionary).definition) as DEF_Package
						var configured: bool = ReceivingPackageFactory.configure_recipe(entity as E_Package,
							definition, String((component.fields as Dictionary).package_id))
						assert(configured, "Package recipe was prevalidated before live mutation")
			entity.id = String(record.entity_id)
			ECS.world.add_entity(entity)
		for component: Dictionary in record.components:
			var script: Script = SaveDataCodec.component_script(String(component.type))
			var target: Component = entity.get_component(script) as Component
			if target == null:
				target = script.new() as Component
				entity.add_component(target)
			SaveDataCodec.apply_fields(target, component.fields as Dictionary)
			if target is C_CustomerFlow:
				# Rebuild day/phase preparation from restored authority, including in-place loads.
				var flow: C_CustomerFlow = target as C_CustomerFlow
				flow.planning_day = 0
				flow.planning_phase = -1
				flow.arrival_cooldown_seconds = 0.0
			if target is C_District:
				var district: C_District = target as C_District
				district.lifecycle_day = 0
				district.lifecycle_phase = -1
			if target is C_Package:
				(target as C_Package).condition_initialized = true
			if target is C_LootDrops:
				var queue: C_LootDrops = target as C_LootDrops
				queue.retry_revision += 1
				queue.retry_queued = false
				queue.retry_remaining = 0.0
				queue.reservations.clear()
				queue.reservation_frame = -1
		# Rebuild unsaved recipe configuration while preserving overlaid durable health.
		if entity is E_Package:
			PackageConditionService.initialize(entity, true)

		var stamina: C_Stamina = entity.get_component(C_Stamina) as C_Stamina
		if stamina != null:
			stamina.toggled = false
			stamina.running = false
			stamina.exhausted = false
			stamina.recovery_remaining = 0.0
			stamina.drain_multiplier = 1.0

		var restored_motion: C_Motion = entity.get_component(C_Motion) as C_Motion
		if restored_motion != null:
			restored_motion.sprint_multiplier = 1.0

		PersistentInteractionState.restore(record.get("completed_actions", []) as Array, entity)

		var node: Node3D = entity as Node as Node3D
		if node != null and record.has("pose"):
			node.global_transform = record.pose as Transform3D
		var body: RigidBody3D = node as RigidBody3D
		var character_body: CharacterBody3D = node as CharacterBody3D
		if character_body != null:
			character_body.velocity = Vector3.ZERO
			var motion: C_Motion = entity.get_component(C_Motion) as C_Motion
			if motion != null:
				motion.pending_impulse = Vector3.ZERO
				motion.sprint_multiplier = 1.0
			var kinematic: C_CharacterBody = entity.get_component(C_CharacterBody) as C_CharacterBody
			if kinematic != null:
				kinematic.impulse_velocity = Vector3.ZERO
				kinematic.pending_rebound_velocity = Vector3.ZERO
				kinematic.contact_bodies.clear()
		if body != null:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			if entity is E_Package:
				var definition: DEF_Package = (entity.get_component(C_Package) as C_Package).definition
				body.mass = definition.empty_mass_kg if PackageContentsService.is_empty(entity) else definition.mass_kg

		if record.death and not entity.has_component(C_Death):
			entity.add_component(C_Death.new())
		elif not record.death and entity.has_component(C_Death):
			entity.remove_component(C_Death)

		if record.has("ink"):
			var marks: C_PackageMarks = entity.get_component(C_PackageMarks) as C_PackageMarks
			if marks == null:
				marks = C_PackageMarks.new()
				entity.add_component(marks)
			marks.strokes.clear()
			marks.point_count = 0
			for saved: Dictionary in record.ink:
				var stroke: PackageMarkStroke = PackageMarkStroke.new()
				stroke.points = saved.points as PackedVector3Array
				stroke.normal = saved.normal as Vector3
				stroke.width = float(saved.width)
				stroke.color = saved.color as Color
				marks.strokes.append(stroke)
				marks.point_count += stroke.points.size()
			marks.revision += 1

		if body != null and record.has("anchor"):
			var anchored: C_PlayerAnchored = C_PlayerAnchored.new()
			anchored.snapshot = AnchoredBodySnapshot.new()
			anchored.snapshot.freeze = bool(record.anchor.freeze)
			anchored.snapshot.freeze_mode = int(record.anchor.freeze_mode) as RigidBody3D.FreezeMode
			anchored.snapshot.can_sleep = bool(record.anchor.can_sleep)
			entity.add_component(anchored)
			body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			body.freeze = true

	for record: Dictionary in data.entities:
		var entity: Entity = entities[String(record.key)]
		for link: Dictionary in record.links:
			var target: Entity = entities[String(link.target)]
			var already_bound: bool = false
			for existing: Relationship in entity.relationships:
				if existing.target == target and ((String(link.kind) == SnapshotLinks.OWNED and existing.relation is R_OwnedBy) or (String(link.kind) == SnapshotLinks.STORED and existing.relation is R_StoredIn) or (String(link.kind) == SnapshotLinks.CARGO and existing.relation is R_CartCargo)):
					already_bound = true
			if already_bound:
				continue

			match String(link.kind):
				SnapshotLinks.OWNED:
					entity.add_relationship(Relationship.new(R_OwnedBy.new(), target))
				SnapshotLinks.STORED:
					var binding: Relationship = Relationship.new(R_StoredIn.new(), target)
					entity.add_relationship(binding)
					PhysicalSlotService.attach(entity, binding)
				SnapshotLinks.CARGO:
					var cargo: R_CartCargo = R_CartCargo.new()
					cargo.local_pose = link.local_pose as Transform3D
					var binding: Relationship = Relationship.new(cargo, target)
					entity.add_relationship(binding)
					CartCargoService.cargo_added(entity, binding)

	for record: Dictionary in data.entities:
		var entity: Entity = entities[String(record.key)]
		if entity.has_component(C_Hazard):
			PersistentHazardState.restore(record.get("hazard_refs", {}) as Dictionary, entity, entities)
	# Setup-observers требуют включённых prefab; сохранённое отключение применяется последним.

	for record: Dictionary in data.entities:
		if not bool(record.enabled):
			ECS.world.disable_entity(entities[String(record.key)])
	for zone: Entity in ECS.world.query.with_all([C_OrderReceiving]).execute():
		OrderDeliveryService.reset_context(zone.get_component(C_OrderReceiving) as C_OrderReceiving)
	for zone: Entity in ECS.world.query.with_all([C_Receiving]).execute():
		ReceivingDeliveryService.reset_context(zone.get_component(C_Receiving) as C_Receiving)
	RefusalQuestService.restore_bindings()
	DistrictPopulationService.restore_participation()
	SnapshotRestoreBoundary.finish(ECS.world, activity)
	return true


#endregion

#region Внутренние ограничения
static func _valid_ids(records: Array, entities: Dictionary[String, Entity]) -> bool:
	for record: Dictionary in records:
		var existing: Entity = ECS.world.entity_id_registry.get(String(record.entity_id)) as Entity
		if is_instance_valid(existing) and existing not in entities.values() and (not _persistent(existing) or (existing.owner != null and not (existing as Node) is RigidBody3D)):
			return false
	return true


static func _persistent(entity: Entity) -> bool:
	if (entity.has_component(C_CustomerAgent) and not entity.has_component(C_NpcIdentity)) or entity.has_component(C_QuestBinding) or entity.has_component(C_CombatProjectile):
		return false
	if entity.has_component(C_HazardLifetime):
		var lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
		return lifetime.persistent and not lifetime.owner_loss_pending
	return (entity as Node) is PhysicsBody3D or entity is E_PhysicalSlot or not PersistentInteractionState.completed(entity).is_empty() or entity.components.values().any(func(value: Variant) -> bool: return value is Component and not SaveDataCodec.component_data(value as Component).is_empty())

#endregion


#region Разрешённые пути сцен сущностей
static func _entity_scene_path_allowed(scene: String) -> bool:
	for directory: String in _ENTITY_SCENE_ROOTS:
		if scene.begins_with(directory):
			return true
	return false
#endregion
