extends Node3D
## Projects transient forms onto authored meshes without modifying physics or AI.
class_name NpcVeilPresentation

const HUMAN_PATHS: Array[String] = ["Body", "Message", "DebugStatus", "HungerPerception"]

@onready var _cloud: Node3D = $Cloud

var _original_visibility: Dictionary[Node3D, bool] = { }


#region View lifecycle
func _ready() -> void:
	var actor: E_DistrictNpc = get_parent() as E_DistrictNpc
	actor.role_cleanup_requested.connect(_on_role_cleanup)
	suspend()


func _on_role_cleanup(_request: NpcRoleCleanupRequest) -> void:
	suspend()
#endregion


#region Read-only committed projection
## Captures authored visibility once per concealment, including originally hidden labels.
func synchronize(form: C_NpcVeil.Form) -> void:
	if form == C_NpcVeil.Form.VISIBLE:
		suspend()
		return
	if _original_visibility.is_empty():
		for path: String in HUMAN_PATHS:
			var visual: Node3D = get_parent().get_node_or_null(path) as Node3D
			if visual != null:
				_original_visibility[visual] = visual.visible
	for visual: Node3D in _original_visibility:
		if is_instance_valid(visual):
			visual.visible = false
	_cloud.visible = form == C_NpcVeil.Form.CLOUD


## Restores each visual's pre-concealment value without changing root/body participation.
func suspend() -> void:
	for visual: Node3D in _original_visibility:
		if is_instance_valid(visual):
			visual.visible = _original_visibility[visual]
	_original_visibility.clear()
	if is_instance_valid(_cloud):
		_cloud.visible = false
#endregion
