extends RefCounted
## Save/load is an explicit one-time physical synchronization boundary before simulation.
class_name WorldSnapshotService

const OWNED: String = "owned"
const STORED: String = "stored"
const CARGO: String = "cargo"


static func key_for(entity: Entity, root: Node) -> String:
	var package: C_Package = entity.get_component(C_Package) as C_Package
	if package != null:
		return "package/" + package.package_id
	var identity: C_PersistentIdentity = entity.get_component(C_PersistentIdentity) as C_PersistentIdentity
	if identity != null:
		return identity.key
	if entity.owner != null and root.is_ancestor_of(entity):
		return "scene/" + String(root.get_path_to(entity))
	return "runtime/" + entity.id


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
			var kind: String = OWNED if binding.relation is R_OwnedBy else STORED if binding.relation is R_StoredIn else CARGO if binding.relation is R_CartCargo else ""
			var target: Entity = binding.target as Entity
			if not kind.is_empty() and is_instance_valid(target):
				var link: Dictionary = {"kind": kind, "target": key_for(target, root)}
				if binding.relation is R_CartCargo:
					link.local_pose = (binding.relation as R_CartCargo).local_pose
				links.append(link)
		var node: Node3D = entity as Node as Node3D
		var record: Dictionary = {"key": key_for(entity, root), "entity_id": entity.id, "scene": entity.scene_file_path, "authored_path": String(root.get_path_to(entity)) if entity.owner != null and root.is_ancestor_of(entity) else "", "enabled": entity.enabled, "components": components, "links": links, "death": entity.has_component(C_Death)}
		if node != null:
			record.pose = node.global_transform
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


## Validate the entire payload against the current scene before any world mutation.
static func valid(data: Dictionary, root: Node) -> bool:
	if data.get("version") != AutosaveStore.SCHEMA_VERSION or not data.get("morning_day") is int or int(data.morning_day) < 1 or not data.get("entities") is Array:
		return false
	var keys: Dictionary = {}
	var session_count: int = 0
	for value: Variant in data.entities:
		if not value is Dictionary:
			return false
		var record: Dictionary = value as Dictionary
		if not record.get("authored_path") is String or not record.get("scene") is String:
			return false
		if not record.get("key") is String or not record.get("entity_id") is String or String(record.entity_id).is_empty() or String(record.key).is_empty() or keys.has(record.key) or not record.get("components") is Array or not record.get("links") is Array or not record.get("enabled") is bool or not record.get("death") is bool:
			return false
		keys[record.key] = true
		var authored: String = String(record.get("authored_path", ""))
		var scene: String = String(record.get("scene", ""))
		if not authored.is_empty() and not root.get_node_or_null(NodePath(authored)) is Entity:
			return false
		if authored.is_empty() and not scene.is_empty() and (not scene.begins_with("res://content/entities/") or not ResourceLoader.exists(scene, "PackedScene")):
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
			types[script] = true
			var probe: Component = script.new() as Component
			if not SaveDataCodec.complete_component_data(script, component.fields as Dictionary):
				return false
			if not SaveDataCodec.apply_fields(probe, component.fields as Dictionary):
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
			if probe is C_Health and (not is_finite((probe as C_Health).current) or (probe as C_Health).current < 0.0 or (probe as C_Health).current > (probe as C_Health).value):
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
		for link: Variant in record.links:
			if not link is Dictionary or link.get("kind") not in [OWNED, STORED, CARGO] or not keys.has(link.get("target")):
				return false
			if link.kind == CARGO and not link.get("local_pose") is Transform3D:
				return false
	return session_count == 1


static func restore(data: Dictionary, root: Node) -> bool:
	if not valid(data, root):
		return false
	var entities: Dictionary[String, Entity] = {}
	var fresh: Array[Entity] = []
	# Instantiate all missing prefabs before committing any change.
	for record: Dictionary in data.entities:
		var entity: Entity = root.get_node_or_null(NodePath(String(record.authored_path))) as Entity if not String(record.authored_path).is_empty() else null
		if entity == null:
			for existing: Entity in ECS.world.entities:
				if is_instance_valid(existing) and key_for(existing, root) == String(record.key):
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
		entities[String(record.key)] = entity
	for existing: Entity in ECS.world.entities.duplicate():
		if not is_instance_valid(existing) or not _persistent(existing):
			continue
		if existing not in entities.values() and not entities.has(key_for(existing, root)):
			ECS.world.remove_entity(existing)
	# Clear every old binding before any physical pose or saved binding is restored.
	for entity: Entity in entities.values():
		if entity not in fresh and not entity.enabled:
			ECS.world.enable_entity(entity)
		# Replace runtime ownership under the same guard used by Inventory transfer.
		# Slot/cart removal runs its existing detach boundary before rebinding.
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
	for record: Dictionary in data.entities:
		var entity: Entity = entities[String(record.key)]
		if entity in fresh:
			if entity is E_Package:
				for component: Dictionary in record.components:
					if SaveDataCodec.component_script(String(component.type)) == C_Package:
						(entity as E_Package).package_id = String((component.fields as Dictionary).package_id)
						(entity as E_Package).package_definition = SaveDataCodec.decode((component.fields as Dictionary).definition) as DEF_Package
			entity.id = String(record.entity_id)
			ECS.world.add_entity(entity)
		for component: Dictionary in record.components:
			var script: Script = SaveDataCodec.component_script(String(component.type))
			var target: Component = entity.get_component(script) as Component
			if target == null:
				target = script.new() as Component
				entity.add_component(target)
			SaveDataCodec.apply_fields(target, component.fields as Dictionary)
			if target is C_Package:
				(target as C_Package).condition_initialized = true
		var node: Node3D = entity as Node as Node3D
		if node != null and record.has("pose"):
			node.global_transform = record.pose as Transform3D
		var body: RigidBody3D = node as RigidBody3D
		if body != null:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			if entity is E_Package:
				body.mass = (entity.get_component(C_Package) as C_Package).definition.mass_kg
		if record.death and not entity.has_component(C_Death):
			entity.add_component(C_Death.new())
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
				if existing.target == target and ((String(link.kind) == OWNED and existing.relation is R_OwnedBy) or (String(link.kind) == STORED and existing.relation is R_StoredIn) or (String(link.kind) == CARGO and existing.relation is R_CartCargo)):
					already_bound = true
			if already_bound:
				continue
			match String(link.kind):
				OWNED:
					entity.add_relationship(Relationship.new(R_OwnedBy.new(), target))
				STORED:
					var binding: Relationship = Relationship.new(R_StoredIn.new(), target)
					entity.add_relationship(binding)
					PhysicalSlotService.attach(entity, binding)
				CARGO:
					var cargo: R_CartCargo = R_CartCargo.new()
					cargo.local_pose = link.local_pose as Transform3D
					var binding: Relationship = Relationship.new(cargo, target)
					entity.add_relationship(binding)
					CartCargoService.cargo_added(entity, binding)
		if not bool(record.enabled):
			ECS.world.disable_entity(entity)
	RefusalQuestService.restore_bindings()
	return true


static func _persistent(entity: Entity) -> bool:
	if entity.has_component(C_CustomerAgent) or entity.has_component(C_QuestBinding) or entity.has_component(C_CombatProjectile):
		return false
	if entity.has_component(C_HazardLifetime):
		return (entity.get_component(C_HazardLifetime) as C_HazardLifetime).persistent
	return (entity as Node) is RigidBody3D or entity is E_PhysicalSlot or entity.components.values().any(func(value: Variant) -> bool: return value is Component and not SaveDataCodec.component_data(value as Component).is_empty())
