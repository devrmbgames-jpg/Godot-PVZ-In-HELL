extends SceneTree
## Parser по фактическим путям после регистрации autoload; скрипты загружаются без запуска игровых сцен.

#region Проверка скриптов
func _init() -> void:
	_validate.call_deferred()

func _validate() -> void:
	var failures: int = 0
	var checked: int = 0
	for source_path: String in OS.get_cmdline_user_args():
		var script: GDScript = load(source_path) as GDScript
		checked += 1
		if script == null or not script.can_instantiate():
			failures += 1
	print("District parser: %d checked, %d failed" % [checked, failures])
	quit(1 if failures > 0 else 0)
#endregion
