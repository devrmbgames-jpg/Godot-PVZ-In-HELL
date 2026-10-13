extends Node3D
## Projects the NPC's message onto an authored physical sign; gameplay remains read-only.
class_name NpcSignboard

## Higher role composition may supply text without coupling this native view to its state.
signal text_requested(request: NpcSignTextRequest)

const STREET_HINT: String = "НЕ ОТВОДИ ВЗГЛЯД.\nЯ ПИШУ — ТЫ ЧИТАЕШЬ."

@onready var _text: Label3D = $Text
@onready var _actor: E_DistrictNpc = get_parent() as E_DistrictNpc
@onready var _message: Label3D = _actor.get_node("Message") as Label3D

var _replaced_message: bool = false


#region Native presentation lifecycle
func _ready() -> void:
	_actor.role_cleanup_requested.connect(_on_role_cleanup)
	_suspend()


func _process(_delta: float) -> void:
	if (
		not EntityAvailability.contains(_actor, ECS.world)
		or _actor.has_component(C_Death) or not NpcDialogueService.uses_signboard(_actor)
	):
		_suspend()
		return
	_message.visible = false
	_replaced_message = true
	visible = true
	var message_text: String = _message.text if _actor.has_active_role() else tr(STREET_HINT)
	var request: NpcSignTextRequest = NpcSignTextRequest.new()
	request.text = message_text
	text_requested.emit(request)
	if _text.text != request.text:
		_text.text = request.text


func _on_role_cleanup(_request: NpcRoleCleanupRequest) -> void:
	_suspend()


func _suspend() -> void:
	if _replaced_message:
		_message.visible = true
		_replaced_message = false
	visible = false
	_text.text = ""
#endregion
