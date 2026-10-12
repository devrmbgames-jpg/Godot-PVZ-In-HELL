extends RefCounted
## Explicit transient form transitions; no sensing, timers or scheduled behavior.
class_name NpcVeilService


#region Native task transitions
static func claim(actor: E_DistrictNpc, form: C_NpcVeil.Form, task_id: int) -> bool:
	if (
		not is_instance_valid(actor) or not actor.enabled or actor.has_component(C_Death)
		or actor.process_mode == Node.PROCESS_MODE_DISABLED or task_id == 0
		or form not in [C_NpcVeil.Form.CLOUD, C_NpcVeil.Form.INVISIBLE]
	):
		return false
	var veil: C_NpcVeil = actor.get_component(C_NpcVeil) as C_NpcVeil
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if veil == null or decision == null or decision.active_task_id != task_id:
		return false
	veil.form = form
	veil.task_id = task_id
	_project(actor, form)
	return true


## An older leaf's exit may release only its own current form.
static func release(actor: E_DistrictNpc, task_id: int) -> void:
	if not is_instance_valid(actor):
		return
	var veil: C_NpcVeil = actor.get_component(C_NpcVeil) as C_NpcVeil
	if veil != null and veil.task_id == task_id:
		reset(actor)


## Synchronous participation/profile/death boundary, including actors without a BTPlayer.
static func reset(actor: E_DistrictNpc) -> void:
	var veil: C_NpcVeil = actor.get_component(C_NpcVeil) as C_NpcVeil
	if veil != null:
		veil.form = C_NpcVeil.Form.VISIBLE
		veil.task_id = 0
	_project(actor, C_NpcVeil.Form.VISIBLE)


static func _project(actor: E_DistrictNpc, form: C_NpcVeil.Form) -> void:
	var view: NpcVeilPresentation = actor.get_node_or_null("VeilPresence") as NpcVeilPresentation
	if view != null and view.is_node_ready():
		view.synchronize(form)
#endregion
