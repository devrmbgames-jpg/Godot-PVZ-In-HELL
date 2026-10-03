extends RefCounted
## Validates durable relationship roles/capacity before live ownership changes.
class_name SnapshotGraphRules


static func valid(records: Dictionary[String, Dictionary], components: Dictionary[String, Dictionary]) -> bool:
	var stack_counts: Dictionary[String, int] = {}
	var slot_occupants: Dictionary[String, bool] = {}
	for key: String in records:
		var record: Dictionary = records[key]
		var source: Dictionary = components[key]
		var links: Array = record.links as Array
		if links.size() > 1:
			return false
		for link: Dictionary in links:
			var target_key: String = String(link.target)
			var target: Dictionary = components[target_key]
			var absent_npc_inventory: bool = String(link.kind) == WorldSnapshotService.OWNED and target.has(C_NpcIdentity) and target.has(C_Inventory) and not target.has(C_Death)
			if target_key == key or (not bool(records[target_key].enabled) and not absent_npc_inventory):
				return false
			match String(link.kind):
				WorldSnapshotService.OWNED:
					if not source.has(C_InventoryItem) or source.has(C_Package) or not target.has(C_Inventory):
						return false
					stack_counts[target_key] = stack_counts.get(target_key, 0) + 1
					if stack_counts[target_key] > (target[C_Inventory] as C_Inventory).maximum_stacks:
						return false
				WorldSnapshotService.STORED:
					if not bool(record.enabled) or not record.has("pose") or record.has("anchor") or slot_occupants.has(target_key):
						return false
					slot_occupants[target_key] = true
				WorldSnapshotService.CARGO:
					if not bool(record.enabled) or not record.has("pose") or record.has("anchor") or not (link.local_pose as Transform3D).is_finite():
						return false
	return true


## Prefab engine types and authored slot policies are checked on detached/reused entities.
static func valid_entities(records: Array, entities: Dictionary[String, Entity]) -> bool:
	for record: Dictionary in records:
		var entity: Entity = entities[String(record.key)]
		var saved_types: Dictionary = {}
		for component: Dictionary in record.components:
			saved_types[SaveDataCodec.component_script(String(component.type))] = true
		if entity is E_Package and not saved_types.has(C_Package):
			return false
		if entity is E_Hazard and (not saved_types.has(C_Hazard) or not saved_types.has(C_HazardLifetime)):
			return false
		if entity is E_Hazard:
			var profile: DEF_Hazard = null
			for component: Dictionary in record.components:
				if SaveDataCodec.component_script(String(component.type)) == C_Hazard:
					profile = SaveDataCodec.decode((component.fields as Dictionary).definition) as DEF_Hazard
			if not HazardProfileRules.valid(profile) or (entity is E_ToxicArea and not profile is DEF_ToxicArea) or (entity is E_Explosion and not profile is DEF_Explosion):
				return false
		if entity is E_ToxicArea and not saved_types.has(C_ToxicArea):
			return false
		if entity is E_Explosion and not saved_types.has(C_Explosion):
			return false
		if entity is E_InteractionTestValve and not saved_types.has(C_InteractionToggle):
			return false
		if not record.get("completed_actions", []) is Array or not PersistentInteractionState.valid(record.get("completed_actions", []) as Array, entity):
			return false
		var body: RigidBody3D = entity as Node as RigidBody3D
		if record.has("anchor") and (body == null or _component(entity, C_Anchorable) == null):
			return false
		for link: Dictionary in record.links:
			var target: Entity = entities[String(link.target)]
			match String(link.kind):
				WorldSnapshotService.OWNED:
					if _component(entity, C_Grabbable) != null:
						return false
				WorldSnapshotService.STORED:
					var slot: E_PhysicalSlot = target as E_PhysicalSlot
					var config: C_PhysicalSlot = _component(target, C_PhysicalSlot) as C_PhysicalSlot
					if body == null or slot == null or config == null or not is_instance_valid(slot.anchor) or not is_instance_valid(slot.driver):
						return false
					var mass: float = body.mass
					for saved: Dictionary in record.components:
						if SaveDataCodec.component_script(String(saved.type)) == C_Package:
							mass = (SaveDataCodec.decode((saved.fields as Dictionary).definition) as DEF_Package).mass_kg
					if not is_finite(mass) or mass > config.maximum_mass:
						return false
					if config.filter != null and not ItemAccessService.matches(_component(entity, C_AccessItem) as C_AccessItem, config.filter):
						return false
				WorldSnapshotService.CARGO:
					if body == null or not (target as Node) is PhysicsBody3D or _component(target, C_CartTransport) == null:
						return false
	return true


static func _component(entity: Entity, script: Script) -> Component:
	var current: Component = entity.get_component(script) as Component
	if current != null:
		return current
	for component: Component in entity.component_resources:
		if component.get_script() == script:
			return component
	return null
