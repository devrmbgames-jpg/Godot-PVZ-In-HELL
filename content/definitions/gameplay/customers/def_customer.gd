extends GameDefinition
class_name DEF_Customer

enum DialogueMode { DIRECT, RIDDLE }
enum Introduction { MANUAL, ANNOUNCE_ORDER, FIRST_APPROACH_DIALOGUE }
const MINIMUM_LEAVING_SECONDS: float = 181.0

@export var display_name: String = "Клиент"
## Empty keeps the schedule's shared customer scene / standard service dialogue.
@export_file("*.tscn") var customer_scene_path: String = ""
@export_file("*.dialogue") var dialogue_resource_path: String = ""
## Descriptive authored context for custom dialogue and future behavior; no hidden score.
@export var interests: PackedStringArray = []
@export var accepts_damaged: bool = true
@export var accepts_opened: bool = true
@export var voluntary_refusal: bool = false
## Local drop position for a refused parcel received directly from the player's hands.
@export var refused_parcel_offset: Vector3 = Vector3(0.75, 0.75, 0.0)
@export var dialogue_mode: DialogueMode = DialogueMode.DIRECT
@export var introduction: Introduction = Introduction.MANUAL
@export_range(0.5, 5.0, 0.1) var auto_dialogue_distance: float = 2.0
@export var dialogue_reactions: Array[DEF_CustomerDialogueReaction] = []
@export var challenge: DEF_Challenge = null
@export_range(0, 100) var riddle_wrong_satisfaction_penalty: int = 20
@export var move_speed: float = 1.8
@export var arrival_distance: float = 0.25
@export var approach_timeout: float = 120.0
@export var greeting_seconds: float = 8.0
@export var patience_seconds: float = 720.0
@export var receiving_seconds: float = 4.0
@export_group("Private inspection")
@export var private_inspection: bool = false
@export_range(0.0, 600.0, 1.0, "or_greater") var inspection_seconds: float = 12.0
@export_range(0.0, 1.0) var inspection_unpack_probability: float = 0.0
@export_range(0.0, 1.0) var inspection_keep_probability: float = 1.0
@export_group("")
@export_range(181.0, 3600.0, 1.0, "or_greater") var leaving_seconds: float = MINIMUM_LEAVING_SECONDS
@export var aggressive_seconds: float = 180.0
## Legacy authored property retained for resource compatibility; Godot/Jolt owns gravity.
@export var gravity: float = 20.0
@export var healthy_satisfaction: int = 100
@export var damaged_satisfaction: int = 70
@export var opened_satisfaction: int = 50
@export_range(0.0, 1.0) var complaint_probability: float = 0.85
@export_range(0.0, 1.0) var voluntary_complaint_probability: float = 0.15
@export_range(0.0, 1.0) var false_complaint_probability: float = 0.05
@export_range(0.0, 1.0) var immediate_aggression_probability: float = 0.1
@export_range(0.0, 1.0) var unresolved_complaint_probability: float = 0.25
@export_range(0.0, 1.0) var followup_probability: float = 0.75
@export_range(1, 30) var followup_delay_days: int = 1
@export_range(0, 10) var max_followup_visits: int = 2
@export_range(1, 30) var complaint_delay_days: int = 1
@export_range(1, 30) var retaliation_days: int = 7
