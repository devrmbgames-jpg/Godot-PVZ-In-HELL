extends SceneTree
## Loads offline evidence after project autoload registration.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audit: GDScript = load("res://utils/audit_direct_traits.gd") as GDScript
	audit.new().run()
	quit()
