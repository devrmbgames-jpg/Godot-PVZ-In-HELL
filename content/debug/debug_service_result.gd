extends RefCounted
## Generic result returned by project-owned debug adapters.
class_name DebugServiceResult

var success: bool = false
var message: String = ""
var details: PackedStringArray = []
