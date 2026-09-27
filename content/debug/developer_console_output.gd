extends RefCounted
## Uniform developer-console output formatting.
class_name DeveloperConsoleOutput


static func ok(command: String, details: PackedStringArray = PackedStringArray()) -> void:
	Console.print_line("OK %s" % command)
	for detail: String in details:
		Console.print_line(detail)


static func error(command: String, message: String, hint: String = "") -> void:
	Console.print_error("ERROR %s" % command)
	Console.print_line(message)
	if not hint.is_empty():
		Console.print_line("hint: %s" % hint)
