extends Node
## Thin command frontend; all writes use domain services or explicit Entity glue.

const COMMANDS: Dictionary[String, Array] = {
	"stamina_info": [["target=self"], 0, "Read sprint reserve, capacity, weight drain, recovery timer and control mode."],
	"hunger_info": [["target=self"], 0, "Read hunger, range, tier and multipliers."],
	"hunger_set": [["value"], 1, "Debug override: self hunger in authored 0..maximum; finite values only."],
	"inventory_info": [["target=self"], 0, "Read zero-based occupied slots, stable IDs and quantities."],
	"inventory_give": [["definition_key", "count=1"], 1, "Debug grant; normal ownership/capacity/stack bounds apply. Furniture rejected."],
	"inventory_use": [["slot"], 1, "Consume self item through normal use; slot is zero-based, inspect inventory_info first."],
	"trader_info": [["target"], 0, "Read selected trader profile/hours/prices/courier. Default first live trader."],
	"trader_open": [["target"], 0, "Open normal shop UI within interaction distance. Closes console after successful eligibility preflight."],
	"trader_buy": [["definition_key", "count=1", "target"], 1, "Normal paid purchase, including physical furniture. Enforces catalog/hours/capacity/placement."],
	"trader_delivery": [["definition_key", "count=1", "target"], 1, "Normal paid courier order: item price plus profile fee, authored delivery day."],
	"order_info": [[], 0, "Read receipts and pending/fulfilled deliveries."],
	"order_place": [["definition_key", "count=1"], 1, "Normal paid terminal order; Morning/Evening catalog/price rules apply."],
	"quest_info": [[], 0, "Read refusal-quest state, deadlines and rewards; no stage writes."],
	"npc_info": [["npc"], 1, "Read attack slots, cooldown, current opponent, animation and automatic selection."],
	"npc_attack": [["npc", "melee|ranged", "slot", "victim"], 4, "Request authored NPC attack; zero-based slot0..2. Range/LOS/cooldown required; invalid request preserves current combat."],
	"nav_info": [["npc"], 1, "Read real NavigationAgent path/avoidance and semantic intent."],
	"challenge_info": [["visit|npc"], 1, "Read challenge rule, timer, arrival/departure scope and result."],
	"challenge_start": [["visit|npc", "definition_key"], 2, "Explicit debug start of inactive unconsumed challenge, Day only; no repeat rewards."],
	"challenge_stop": [["visit|npc"], 1, "Explicit debug cancel through challenge lifecycle; releases session/effects."],
	"hazard_info": [["target=target"], 0, "Read autonomous effect lifetime/ownership/origin without removing effects."],
	"save_info": [[], 0, "Morning-only snapshot testing in user://debug_slots/<name>.pvzh. Gameplay autosave never overwritten."],
	"save_write": [["slot"], 1, "Write isolated Morning snapshot. ASCII slot1..32 letters/digits/_/-. No live visit/modal/grip/challenge."],
	"save_load": [["slot"], 1, "Replace world state with validated isolated Morning snapshot; same eligibility as save_write. Missing/corrupt slot leaves world unchanged."],
	"debug_ui": [["on|off"], 1, "Alias for debug_hud; toggles debug overlays including above-client status."],
	"debug_markers": [["on|off"], 1, "Show/hide authored DebugMarkers for this runtime only, no scene edits."],
	"progress_info": [["object"], 1, "Read valve normalized progress0..1 and active state."],
	"progress_set": [["object", "value"], 2, "Debug preview0..1 via glue/progress signal/rotation; hold completion effect not executed. Immediate button allows0/1. Active/completed hold rejected."],
	"corpse_info": [["object"], 1, "Read dead NPC remains one-shot release. Current prototype drops meat immediately; no imaginary hit counter."],
	"meat_spawn": [[], 0, "Debug spawn one authored edible physical meat pickup near self; eat/pick up normally."],
}


func _ready() -> void:
	for command: String in COMMANDS:
		var metadata: Array = COMMANDS[command]
		Console.add_command(command, Callable(self, "_" + command), metadata[0] as Array, int(metadata[1]), String(metadata[2]))
	var keys: PackedStringArray = []
	for definition: GameDefinition in DebugGameplayService.definitions(DebugGameplayService.ITEM_DIRECTORY): keys.append(String(definition.key))
	for command: String in ["inventory_give", "order_place", "trader_buy", "trader_delivery"]: Console.add_command_autocomplete_list(command, keys)


func _exit_tree() -> void:
	for command: String in COMMANDS: Console.remove_command(command)


func _info(command: String, kind: String, raw: String) -> void:
	if raw.is_empty() and kind in ["stamina", "hunger", "inventory"]: raw = "self"
	if raw.is_empty() and kind == "hazard": raw = "target"
	_print(command, DebugGameplayService.info(kind, raw))


func _stamina_info(raw: String = "self") -> void: _info("stamina_info", "stamina", raw)
func _hunger_info(raw: String = "self") -> void: _info("hunger_info", "hunger", raw)
func _inventory_info(raw: String = "self") -> void: _info("inventory_info", "inventory", raw)
func _trader_info(raw: String = "") -> void: _info("trader_info", "trader", raw)
func _order_info() -> void: _info("order_info", "order", "")
func _quest_info() -> void: _info("quest_info", "quest", "")
func _npc_info(raw: String) -> void: _info("npc_info", "npc", raw)
func _nav_info(raw: String) -> void: _info("nav_info", "nav", raw)
func _challenge_info(raw: String) -> void: _info("challenge_info", "challenge", raw)
func _hazard_info(raw: String = "target") -> void: _info("hazard_info", "hazard", raw)
func _progress_info(raw: String) -> void: _info("progress_info", "progress", raw)
func _corpse_info(raw: String) -> void: _info("corpse_info", "corpse", raw)


func _hunger_set(text: String) -> void:
	_report("hunger_set", text.is_valid_float() and HungerService.set_value(DebugTargetResolver.player(), text.to_float()), "Finite value within authored hunger range required; live player only")


func _inventory_give(key: String, count: String = "1") -> void:
	if count.is_empty(): count = "1"
	_report("inventory_give", count.is_valid_int() and InventoryService.grant(DebugTargetResolver.player(), DebugGameplayService.item(key), count.to_int()), "Definition/count unavailable, furniture or inventory full; use help inventory_give")


func _inventory_use(text: String) -> void:
	var actor: Entity = DebugTargetResolver.player()
	var owned: Array[Entity] = InventoryService.items(actor)
	var index: int = text.to_int() if text.is_valid_int() else -1
	_report("inventory_use", index >= 0 and index < owned.size() and InventoryService.use(actor, owned[index]), "Invalid zero-based slot or item unavailable/unusable")


func _trader_open(raw: String = "") -> void:
	var actor: Entity = DebugTargetResolver.player()
	var trader: Entity = DebugGameplayService.trader_for(raw)
	var actor_node: Node3D = actor as Node as Node3D
	var trader_node: Node3D = trader as Node as Node3D
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor if actor != null else null
	var cycle: C_DayCycle = DayPhaseService.current()
	if actor_node == null or trader_node == null or interactor == null or actor_node.global_position.distance_to(trader_node.global_position) > interactor.interaction_distance or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.MODAL:
		_report("trader_open", false, "Live nearby trader and free interaction focus required; Night unavailable")
		return
	if bool(Console.is_visible()): Console.toggle_console()
	_report("trader_open", CommercePanelService.open(actor, trader) != null, "Normal shop UI rejected request")


func _trader_buy(key: String, count: String = "1", raw: String = "") -> void: _trade("trader_buy", key, count, raw, false)
func _trader_delivery(key: String, count: String = "1", raw: String = "") -> void: _trade("trader_delivery", key, count, raw, true)


func _trade(command: String, key: String, count: String, raw: String, courier: bool) -> void:
	if count.is_empty(): count = "1"
	var trader: Entity = DebugGameplayService.trader_for(raw)
	var shop: C_Trader = trader.get_component(C_Trader) as C_Trader if trader != null else null
	var definition: DEF_InventoryItem = null
	if shop != null:
		for offer: DEF_InventoryItem in TraderCatalogService.catalog(shop):
			if offer != null and String(offer.key) == key: definition = offer
	if definition == null or not count.is_valid_int():
		_report(command, false, "Authored trader catalog key and integer count required")
		return

	var operation: StringName = CommerceService.next_id("debug-trader")
	var status: CommerceService.Status = CommerceService.home_delivery(DebugTargetResolver.player(), trader, definition, count.to_int(), operation) if courier else CommerceService.purchase(DebugTargetResolver.player(), trader, definition, count.to_int(), operation)
	_report(command, status == CommerceService.Status.COMMITTED, CommerceService.Status.keys()[status], "trader=%s item=%s quantity=%d operation=%s courier=%s" % [trader.id, definition.key, count.to_int(), operation, courier])


func _order_place(key: String, count: String = "1") -> void:
	if count.is_empty(): count = "1"
	if not count.is_valid_int():
		_report("order_place", false, "Integer count required")
		return

	var operation: StringName = CommerceService.next_id("debug-order")
	var status: CommerceService.Status = CommerceService.order(DebugTargetResolver.player(), DebugGameplayService.item(key), count.to_int(), operation)
	_report("order_place", status == CommerceService.Status.COMMITTED, CommerceService.Status.keys()[status], "item=%s quantity=%d operation=%s" % [key, count.to_int(), operation])


func _npc_attack(raw: String, kind_text: String, index_text: String, victim_text: String) -> void:
	if kind_text not in ["melee", "ranged"] or not index_text.is_valid_int() or index_text.to_int() < 0 or index_text.to_int() >= C_NpcCombat.MAX_VARIANTS:
		_report("npc_attack", false, "kind melee/ranged; zero-based slot0..2")
		return

	var kind: C_NpcCombat.Kind = C_NpcCombat.Kind.MELEE if kind_text == "melee" else C_NpcCombat.Kind.RANGED
	_report("npc_attack", NpcAttackService.start_against(DebugGameplayService.subject(raw), DebugGameplayService.subject(victim_text), kind, index_text.to_int()), "Live authored ability, target, range/LOS and ready cooldown required")


func _challenge_start(raw: String, key: String) -> void:
	var definition: DEF_Challenge = null
	for candidate: GameDefinition in DebugGameplayService.definitions(DebugGameplayService.CHALLENGE_DIRECTORY):
		if String(candidate.key) == key: definition = candidate as DEF_Challenge
	_report("challenge_start", ChallengeService.debug_start(DebugGameplayService.subject(raw), DebugTargetResolver.player(), definition), "Explicit debug start rejected: authored key, live unconsumed subject and Day required")


func _challenge_stop(raw: String) -> void:
	var subject: Entity = DebugGameplayService.subject(raw)
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge if subject != null else null
	if state == null or state.phase in [C_Challenge.Phase.INACTIVE, C_Challenge.Phase.CLEANUP]:
		_report("challenge_stop", false, "No challenge session to cancel")
		return

	ChallengeService.cancel(subject)
	_report("challenge_stop", true, "")


func _save_info() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	DeveloperConsoleOutput.ok("save_info", PackedStringArray(["isolated_directory=%s; gameplay_autosave_untouched=true" % DebugGameplayService.SLOT_DIRECTORY, "phase=%s; Morning only, no live customers/modal/grip/challenge" % (C_DayCycle.Phase.keys()[cycle.phase] if cycle != null else "none")]))


func _save_write(slot: String) -> void: _print("save_write", DebugGameplayService.save_slot(slot, true))
func _save_load(slot: String) -> void: _print("save_load", DebugGameplayService.save_slot(slot, false))


func _debug_ui(mode: String) -> void:
	if mode not in ["on", "off"]:
		_report("debug_ui", false, "on or off required")
		return

	DebugHudService.set_enabled(mode == "on")
	_report("debug_ui", true, "")


func _debug_markers(mode: String) -> void:
	var root: Node = ECS.world.get_parent() if is_instance_valid(ECS.world) else null
	var markers: Node3D = root.get_node_or_null("DebugMarkers") as Node3D if root != null else null
	if mode not in ["on", "off"] or markers == null:
		_report("debug_markers", false, "on/off and authored DebugMarkers node required")
		return

	markers.visible = mode == "on"
	_report("debug_markers", true, "")


func _progress_set(raw: String, text: String) -> void:
	var valve: E_InteractionTestValve = DebugGameplayService.subject(raw) as E_InteractionTestValve
	_report("progress_set", valve != null and text.is_valid_float() and valve.set_progress(text.to_float()), "Finite0..1; supported valve; no active/completed hold. Immediate button permits0/1")


func _meat_spawn() -> void: _print("meat_spawn", DebugGameplayService.meat_spawn())


func _report(command: String, committed: bool, error: String, details: String = "") -> void:
	var actor: Entity = DebugTargetResolver.player()
	var lines: PackedStringArray = ["committed=true actor=%s" % (actor.id if actor != null else "none")]
	if not details.is_empty(): lines.append(details)
	_print(command, DebugGameplayService.success(lines) if committed else DebugGameplayService.failure(error))


func _print(command: String, result: DebugServiceResult) -> void:
	if result.success: DeveloperConsoleOutput.ok(command, result.details)
	else: DeveloperConsoleOutput.error(command, result.message)
