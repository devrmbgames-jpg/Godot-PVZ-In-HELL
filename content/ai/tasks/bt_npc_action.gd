@tool
extends BTAction
## Основа листового действия; токен защищает движение новой ветки от старого _exit.

## Единственный приоритет, с которым действие запрашивает физическое намерение.
@export var intent_owner: C_NpcDecision.Owner = C_NpcDecision.Owner.IDLE

var _actor: E_DistrictNpc
var _person: NpcRecord
var _awareness: C_NpcAwareness
var _owns_movement: bool = false

#region Контекст и жизненный цикл
func _setup() -> void:
	_actor = get_agent() as E_DistrictNpc
	if not is_instance_valid(_actor):
		return
	var identity: C_NpcIdentity = _actor.get_component(C_NpcIdentity) as C_NpcIdentity
	_person = DistrictPopulationService.person_for(identity.npc_id) if identity != null else null
	_awareness = _actor.get_component(C_NpcAwareness) as C_NpcAwareness

func _enter() -> void:
	_owns_movement = false

func _exit() -> void:
	if not _owns_movement or not is_instance_valid(_actor):
		return
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision != null and decision.active_task_id == get_instance_id():
		NpcIntentArbiter.stop(_actor, intent_owner)
		decision.active_task_id = 0

func _claim(behavior: String) -> bool:
	if not is_instance_valid(_actor) or not NpcIntentArbiter.acquire(_actor, intent_owner, behavior):
		return false
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision != null:
		decision.active_task_id = get_instance_id()
	return true

func _move(destination: Vector3, distance: float) -> void:
	_owns_movement = true
	NpcIntentArbiter.move_to(_actor, destination, distance, intent_owner)

func _visit() -> CustomerVisit:
	return NpcServiceRole.visit_for(_actor)

func _service() -> C_CustomerAgent:
	return _actor.get_component(C_CustomerAgent) as C_CustomerAgent

func _intent() -> C_NpcIntent:
	return _actor.get_component(C_NpcIntent) as C_NpcIntent
#endregion
