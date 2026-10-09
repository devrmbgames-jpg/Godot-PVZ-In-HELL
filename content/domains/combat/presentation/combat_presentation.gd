extends RefCounted
## Читает состояние боя для отладочной сводки без выбора и запуска атак.
class_name CombatPresentation

const NPC_PHASES: Array[String] = ["готов", "замах", "удар / выстрел", "восстановление"]
const PLAYER_PHASES: Array[String] = ["готов", "замах", "удар", "восстановление"]
const DEFAULT_COLLISION_MASK: int = 31


## Собирает фазы, таймеры и дистанцию текущих противников участника.
static func debug_text(actor: Entity) -> String:
	var lines: PackedStringArray = []
	var player: C_Combat = actor.get_component(C_Combat) as C_Combat if is_instance_valid(actor) else null
	if player != null:
		lines.append("БОЙ · нож в руке: ЛКМ / Alt+ЛКМ бросить")
		lines.append("Игрок: %s · таймер %.2f c" % [PLAYER_PHASES[player.phase], player.elapsed])
	if not is_instance_valid(ECS.world):
		return "\n".join(lines)

	for npc: Entity in ECS.world.query.with_all([C_NpcCombat]).execute():
		var target: Entity = CombatQueries.target_for(npc)
		if target != actor:
			continue

		var state: C_NpcCombat = npc.get_component(C_NpcCombat) as C_NpcCombat
		var health: C_Health = npc.get_component(C_Health) as C_Health
		var kind: String = "ближняя" if state.kind == C_NpcCombat.Kind.MELEE else "дальняя"
		lines.append("Задача: защититься от клиента · HP %.0f" % [health.current if health != null else 0.0])
		lines.append("NPC: %s · %s %s" % [NPC_PHASES[state.phase], kind, "#%d" % (state.variant + 1) if state.variant >= 0 else "—"])
		lines.append("Таймер %.2f c · cooldown %.2f c" % [state.elapsed, state.cooldown_remaining])
		lines.append("Ближние: %s\nДальние: %s" % [_ranges(state.melee_attacks), _ranges(state.ranged_attacks)])
		var npc_node: Node3D = npc as Node as Node3D
		var actor_node: Node3D = actor as Node as Node3D
		lines.append("Дистанция %.1f м · линия %s" % [npc_node.global_position.distance_to(actor_node.global_position), "открыта" if CombatGeometry.clear_line(npc, actor, state.attack.collision_mask if state.attack != null else DEFAULT_COLLISION_MASK) else "закрыта"])
		if state.attack != null:
			lines.append("Условие %.1f–%.1f м · %s" % [state.attack.minimum_range, state.attack.maximum_range, "анимация" if state.animation_driven else "таймер"])
		var agent: C_CustomerAgent = npc.get_component(C_CustomerAgent) as C_CustomerAgent
		var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id) if agent != null else null
		if visit != null:
			lines.append("Конфликт: осталось %.1f c" % [maxf(0.0, visit.definition.aggressive_seconds - agent.elapsed)])
	return "\n".join(lines)


static func _ranges(attacks: Array[DEF_NpcAttack]) -> String:
	var values: PackedStringArray = []
	for index: int in mini(attacks.size(), C_NpcCombat.MAX_VARIANTS):
		var attack: DEF_NpcAttack = attacks[index]
		if attack != null:
			values.append("%d: %.1f–%.1f м" % [index + 1, attack.minimum_range, attack.maximum_range])
	return "; ".join(values) if not values.is_empty() else "нет"
