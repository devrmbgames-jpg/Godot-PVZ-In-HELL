extends Node
## Проектная справка и управление мышью/фокусом консоли; игровые запросы исполняют другие адаптеры.

const GROUPS: PackedStringArray = ["packages", "customers", "economy", "health", "inventory", "trader", "npc", "challenges", "world"]
const WHEEL_LINES: float = 3.0
const EXAMPLES: Dictionary[String, String] = {
	"pkg_spawn": "pkg_spawn books 1 receiving 1",
	"pkg_actual": "pkg_actual target delivered",
	"pkg_declare": "pkg_declare target taken",
	"visit_create": "visit_create target default",
	"apply_damage": "apply_damage target 10 melee",
	"heal": "heal self 20",
	"money_add": "money_add 500 qa",
	"money_remove": "money_remove 20 qa",
	"debug_hud": "debug_hud off",
	"stamina_info": "stamina_info self",
	"hunger_info": "hunger_info self",
	"hunger_set": "hunger_set 50",
	"inventory_info": "inventory_info self",
	"inventory_give": "inventory_give food 2",
	"inventory_use": "inventory_use 0",
	"trader_info": "trader_info",
	"trader_open": "trader_open target",
	"trader_buy": "trader_buy large_shelf 1",
	"trader_delivery": "trader_delivery large_shelf 1",
	"order_info": "order_info",
	"order_place": "order_place med 2",
	"quest_info": "quest_info",
	"npc_info": "npc_info target",
	"npc_attack": "npc_attack target melee 0 self",
	"nav_info": "nav_info target",
	"challenge_info": "challenge_info target",
	"challenge_start": "challenge_start target warehouse-light-during-visit",
	"challenge_stop": "challenge_stop target",
	"hazard_info": "hazard_info target",
	"save_info": "save_info",
	"save_write": "save_write qa_console",
	"save_load": "save_load qa_console",
	"debug_ui": "debug_ui off",
	"debug_markers": "debug_markers on",
	"progress_info": "progress_info target",
	"progress_set": "progress_set target 0.5",
	"corpse_info": "corpse_info target",
	"meat_spawn": "meat_spawn",
}

var _previous_help: Console.ConsoleCommand
var _previous_help_subjects: PackedStringArray = []
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _previous_focus: WeakRef
var _mouse_acquired: bool = false


#region Справка и подключения
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_help = Console.console_commands.get("help") as Console.ConsoleCommand
	_previous_help_subjects = Console.command_parameters.get("help", PackedStringArray())
	Console.add_command("help", _help, ["command|group"], 0, "Show built-in instructions and project command/group syntax.")
	var subjects: PackedStringArray = GROUPS.duplicate()
	subjects.append_array(Console.console_commands.keys())
	Console.add_command_autocomplete_list("help", subjects)
	Console.add_command_autocomplete_list("debug_help", subjects)
	Console.rich_label.scroll_active = true
	Console.console_opened.connect(_opened)
	Console.console_closed.connect(_closed)
	Console.rich_label.gui_input.connect(_output_input)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	if bool(Console.is_visible()):
		_opened()
	
	Console.font_size = 12


func _exit_tree() -> void:
	_closed()
	Console.console_opened.disconnect(_opened)
	Console.console_closed.disconnect(_closed)
	Console.rich_label.gui_input.disconnect(_output_input)
	get_viewport().gui_focus_changed.disconnect(_focus_changed)
	if _previous_help != null:
		Console.console_commands["help"] = _previous_help
		Console.add_command_autocomplete_list("help", _previous_help_subjects)


#endregion

#region Мышь и возврат фокуса
func _opened() -> void:
	if _mouse_acquired:
		return

	_mouse_acquired = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Console.rich_label.scroll_following = true


func _process(_delta: float) -> void:
	# Диалог под консолью может завершиться по таймеру; открытая консоль сохраняет видимую мышь.
	if _mouse_acquired and bool(Console.is_visible()) and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _closed() -> void:
	if not _mouse_acquired:
		return

	_mouse_acquired = false
	var actor: Entity = DebugTargetResolver.player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.MODAL else _previous_mouse_mode
	if _previous_focus != null:
		var control: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(control) and control.is_visible_in_tree():
			control.grab_focus()


func _focus_changed(control: Control) -> void:
	if not Console.v_box_container.is_ancestor_of(control):
		_previous_focus = weakref(control)


#endregion

#region Прокрутка и справка
func _output_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.is_command_or_control_pressed():
		return

	var direction: float = 0.0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1.0
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1.0
	else:
		return

	var scroll: VScrollBar = Console.rich_label.get_v_scroll_bar()
	var line_height: float = float(Console.rich_label.get_theme_font_size("normal_font_size"))
	scroll.value += direction * WHEEL_LINES * line_height * button.factor
	Console.rich_label.accept_event()


func _help(subject: String = "") -> void:
	var name_text: String = subject.strip_edges().to_lower()
	if name_text.is_empty():
		if _previous_help != null:
			_previous_help.function.call()
		Console.print_line("Available commands:")
		Console.commands_list()
		Console.print_line("Project groups: %s" % ", ".join(GROUPS))
		Console.print_line("help <command|group>; debug_help is an alias. Targets: self | target | pkg:<id> | visit:<id> | entity:<id>")
		Console.print_line("Examples: help inventory; help pkg_spawn; help npc; help world. commands_list includes addon commands.")
		return
	if GROUPS.has(name_text):
		for command_name: String in Console.console_commands:
			var entry: Console.ConsoleCommand = Console.console_commands[command_name]
			if not entry.hidden and _group(command_name) == name_text:
				_print_command(command_name, entry)
		_print_workflow(name_text)
		return

	var command: Console.ConsoleCommand = Console.console_commands.get(name_text) as Console.ConsoleCommand
	if command == null or command.hidden:
		DeveloperConsoleOutput.error("help", "Unknown subject: %s" % name_text, "Groups: %s; registered names: commands_list." % ", ".join(GROUPS))
		return

	_print_command(name_text, command)


func _print_command(command_name: String, command: Console.ConsoleCommand) -> void:
	var syntax: String = command_name
	for index: int in command.arguments.size():
		var argument: String = command.arguments[index]
		syntax += " <%s>" % argument if index < command.required else " [%s]" % argument
	# Console поддерживает BBCode: квадратные скобки синтаксиса выводятся буквально.
	Console.print_line(syntax.replace("[", "[lb]"))
	Console.print_line(command.description)
	if EXAMPLES.has(command_name):
		Console.print_line("Example: %s" % EXAMPLES[command_name])
	Console.print_line("Domain eligibility is enforced. Mutation commands are explicit QA actions; info/help commands are read-only.")


func _print_workflow(group_name: String) -> void:
	match group_name:
		"inventory", "health": Console.print_line("Food: hunger_set 50 -> inventory_give food 2 -> inventory_info -> inventory_use 0 -> hunger_info. Meat: kill target -> meat_spawn -> normal pickup/eat.")
		"trader": Console.print_line("Commerce: trader_info -> money_add 500 qa -> trader_buy large_shelf 1 / trader_delivery large_shelf 1. Orders: order_place med 2 -> order_info -> normal day_next until next Morning -> order_info.")
		"customers", "challenges": Console.print_line("Live client: pkg_spawn books 1 receiving 1 -> visit_create pkg:<id> ordinary 1 (if no visit) -> day_next -> customer_next -> visit_info pkg:<id> -> challenge_info visit:<id>. Departure completes visit-scoped challenges.")
		"npc": Console.print_line("Combat: npc_info target -> npc_attack target melee 0 self -> health_info self. Kill NPC, inspect remains/physical meat, pick up and consume normally.")
		"world": Console.print_line("Valve: progress_info target -> progress_set target 0.5. Save: Morning/no live sessions -> save_write qa_console -> change state -> save_load qa_console -> inspect restored facts. Load replaces Morning world state; default autosave untouched.")


func _group(command_name: String) -> String:
	if command_name.begins_with("pkg_"): return "packages"
	if command_name.begins_with("visit_") or command_name.begins_with("complaint_") or command_name == "customer_next": return "customers"
	if command_name.begins_with("money_") or command_name.begins_with("penalty_") or command_name == "wallet_info": return "economy"
	if command_name.begins_with("hunger_") or command_name.begins_with("stamina_") or command_name in ["health_info", "apply_damage", "heal", "kill", "reset", "corpse_info", "meat_spawn"]: return "health"
	if command_name.begins_with("inventory_"): return "inventory"
	if command_name.begins_with("trader_") or command_name.begins_with("order_") or command_name == "quest_info": return "trader"
	if command_name.begins_with("npc_") or command_name == "nav_info": return "npc"
	if command_name.begins_with("challenge_") or command_name == "hazard_info": return "challenges"
	if command_name.begins_with("day_") or command_name.begins_with("debug_") or command_name.begins_with("save_") or command_name.begins_with("progress_"): return "world"
	return ""

#endregion
