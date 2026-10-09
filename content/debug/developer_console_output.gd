extends RefCounted
## Единый вывод успеха/ошибки проектных команд через Console.
class_name DeveloperConsoleOutput


## Выводит имя принятой команды и строки результата.
static func ok(command: String, details: PackedStringArray = PackedStringArray()) -> void:
	Console.print_line("OK %s" % command)
	for detail: String in details:
		Console.print_line(detail)


## Выводит имя отклонённой команды, причину и необязательную подсказку.
static func error(command: String, message: String, hint: String = "") -> void:
	Console.print_error("ERROR %s" % command)
	Console.print_line(message)
	if not hint.is_empty():
		Console.print_line("hint: %s" % hint)
