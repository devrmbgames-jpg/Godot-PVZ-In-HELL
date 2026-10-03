extends RefCounted
## Physical unowned drops use normal inventory lifecycle and survive the visitor's removal.
class_name NpcRemainsService

const GROUND_PROBE_RISE: float = 0.25
const GROUND_PROBE_DEPTH: float = 20.0
const SUPPORT_CLEARANCE: float = 0.03
const GROUND_MASK: int = 31


static func release(npc: Entity) -> void:
	if not EntityAvailability.contains(npc, ECS.world):
		return
	var state: C_NpcRemains = npc.get_component(C_NpcRemains) as C_NpcRemains
	var health: C_Health = npc.get_component(C_Health) as C_Health
	var body: PhysicsBody3D = npc as Node as PhysicsBody3D
	if state == null or state.released or state.definition == null or body == null:
		return
	if health == null or not health.depleted:
		return
	var definition: DEF_NpcRemains = state.definition
	if definition.meat_scene == null or definition.meat_piece_count < 1 or definition.meat_piece_count > DEF_NpcRemains.MAX_MEAT_PIECES:
		return
	var scenes: Array[PackedScene] = []
	for index: int in definition.meat_piece_count:
		scenes.append(definition.meat_scene)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(npc.id)
	if definition.loot_scene != null and random.randf() < clampf(definition.loot_chance, 0.0, 1.0):
		scenes.append(definition.loot_scene)
	var drops: Array[Entity] = []
	for scene: PackedScene in scenes:
		var node: Node = scene.instantiate()
		var drop: Entity = node as Entity
		if drop == null or not node is PhysicsBody3D or not _individual_pickup(drop):
			node.free()
			for pending: Entity in drops:
				pending.free()
			return
		drops.append(drop)
	# Commit before registering any Entity. Reentrant observers cannot create another batch.
	state.released = true
	for index: int in drops.size():
		var drop: Entity = drops[index]
		var node: Node3D = drop as Node as Node3D
		var angle: float = TAU * float(index) / float(drops.size())
		var position: Vector3 = body.global_position + Vector3(cos(angle), 0, sin(angle)) * definition.piece_spacing
		var start: Vector3 = position + Vector3.UP * GROUND_PROBE_RISE
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			start, start + Vector3.DOWN * GROUND_PROBE_DEPTH, GROUND_MASK,
		)
		ray.exclude = [body.get_rid()]
		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			position.y = (hit.position as Vector3).y - _bottom_height(node) + SUPPORT_CLEARANCE
		body.get_parent().add_child(node)
		node.global_position = position
		ECS.world.add_entity(drop, null, false)
	var character: E_NpcCharacter = npc as E_NpcCharacter
	if character != null:
		character.sync_death_presentation()


static func _individual_pickup(drop: Entity) -> bool:
	var components: Array[Component] = drop.component_resources.duplicate()
	for index: int in components.size():
		var item: C_InventoryItem = components[index] as C_InventoryItem
		if item == null:
			continue
		if item.definition == null or item.definition.key == &"":
			return false
		var single: C_InventoryItem = C_InventoryItem.new()
		single.definition = item.definition
		single.quantity = 1
		components[index] = single
		drop.component_resources = components
		return true
	return false


static func _bottom_height(node: Node3D) -> float:
	var lowest: float = 0.0
	for child: Node in node.find_children("*", "CollisionShape3D", true, false):
		var collision: CollisionShape3D = child as CollisionShape3D
		if collision.shape == null or collision.disabled:
			continue
		var mesh: ArrayMesh = collision.shape.get_debug_mesh()
		var relative: Transform3D = collision.transform
		var ancestor: Node = collision.get_parent()
		while ancestor != null and ancestor != node:
			if ancestor is Node3D:
				relative = (ancestor as Node3D).transform * relative
			ancestor = ancestor.get_parent()
		var bounds: AABB = relative * mesh.get_aabb()
		lowest = minf(lowest, bounds.position.y)
	return lowest
