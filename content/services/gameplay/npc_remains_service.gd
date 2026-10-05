extends RefCounted
## Фиксирует бесхозную добычу погибшего NPC; её размещение переживает удаление тела и загрузку.
class_name NpcRemainsService

#region Однократная партия добычи
## Фиксирует guard и состав до регистрации тел; занятое место сохраняет предмет в сессионной очереди.
static func release(npc: Entity) -> void:
	if not EntityAvailability.contains(npc, ECS.world):
		return

	var state: C_NpcRemains = npc.get_component(C_NpcRemains) as C_NpcRemains
	var health: C_Health = npc.get_component(C_Health) as C_Health
	var body: PhysicsBody3D = npc as Node as PhysicsBody3D
	if state == null or state.released or state.definition == null or body == null or health == null or not health.depleted:
		return

	var definition: DEF_NpcRemains = state.definition
	if definition.meat_scene == null or definition.meat_piece_count < 1 or definition.meat_piece_count > DEF_NpcRemains.MAX_MEAT_PIECES:
		return
	var queue: C_LootDrops = LootDropService.current()
	if queue == null:
		return
	var scenes: Array[PackedScene] = []
	for index: int in definition.meat_piece_count:
		scenes.append(definition.meat_scene)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(npc.id)
	if definition.loot_scene != null and random.randf() < clampf(definition.loot_chance, 0.0, 1.0):
		scenes.append(definition.loot_scene)
	var items: Array[Entity] = LootDropService.prepare(scenes, true)
	if items.is_empty():
		return

	var template: PendingLootDrop = PendingLootDrop.new()
	template.anchor = body.global_position
	template.source_id = npc.id
	template.ignore_source = true
	var origins: PackedVector3Array = PackedVector3Array()
	for index: int in items.size():
		var angle: float = TAU * float(index) / float(items.size())
		origins.append(body.global_position + Vector3(cos(angle), 0.0, sin(angle)) * definition.piece_spacing)

	state.released = true
	LootDropService.enqueue(queue, "npc/" + npc.id + "/remains", items, template, origins)
	var character: E_NpcCharacter = npc as E_NpcCharacter
	if character != null:
		character.sync_death_presentation()
#endregion
