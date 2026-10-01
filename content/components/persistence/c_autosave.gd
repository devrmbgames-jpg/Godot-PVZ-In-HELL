extends Component
class_name C_Autosave

@export var path: String = AutosaveStore.DEFAULT_PATH
@export var retry_seconds: float = 1.0
var started_night: int = 0
var last_saved_morning: int = 0
var retry_remaining: float = 0.0
var last_error: Error = OK
var startup_status: String = "Новое прохождение"
