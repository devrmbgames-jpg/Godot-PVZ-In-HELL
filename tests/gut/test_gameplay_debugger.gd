extends "res://tests/gut/test_district_population.gd"
## Exercises detached production diagnostics, dormant selections and native console teardown.

const VIEW: PackedScene = preload("res://content/debug/gameplay_debugger_view.tscn")
const AUTHORING_VIEW: PackedScene = preload(
	"res://content/editor/entity_authoring/entity_authoring_dock.tscn"
)


#region Data provider acceptance
func test_npc_snapshot_explains_current_obligation_without_advancing_native_tree() -> void:
	var person: NpcRecord = _district.people[0]
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	decision.selection_reason = &"priority_preemption"
	decision.action_status = C_NpcDecision.ActionStatus.CANCELLED
	decision.action_reason = &"service_started"
	var runner: BTPlayer = actor.get_node("Brain") as BTPlayer
	var previous_status: int = runner.get_bt_instance().get_root_task().get_status()
	var previous_generation: int = decision.action_generation
	var previous_entities: int = _world.entities.size()
	var state: Dictionary[String, Variant] = GameplayDebuggerData.snapshot(actor)
	assert_eq(state["decision"]["selection_reason"], "priority_preemption")
	assert_eq(state["decision"]["action_status"], "CANCELLED")
	assert_eq(state["decision"]["action_reason"], "service_started")
	assert_eq(state["obligation"]["goal"], String(person.goal_id))
	assert_eq(state["limboai"]["node"], String(runner.get_path()))
	assert_eq(state["limboai"]["instance_id"], runner.get_bt_instance().get_instance_id())
	assert_true(state["components"].has("C_NpcIntent"))
	assert_true(state.has("intent") and state.has("perception") and state.has("simulation_lod"))
	assert_eq(runner.get_bt_instance().get_root_task().get_status(), previous_status)
	assert_eq(decision.action_generation, previous_generation)
	assert_eq(_world.entities.size(), previous_entities)
	assert_false(_contains_object(state), "No live gameplay references escape the snapshot")


func test_dormant_body_remains_selectable_without_enabling_physical_or_ai_work() -> void:
	var person: NpcRecord = _district.people[0]
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	assert_true(DistrictPopulationService.set_placement(person, actor, NpcRecord.Placement.HOME))
	var generation: int = (
		actor.get_component(C_NpcDecision) as C_NpcDecision
	).participation_generation
	var selected: Entity = GameplayDebuggerData.resolve("entity:" + actor.id)
	assert_same(selected, actor)
	var state: Dictionary[String, Variant] = GameplayDebuggerData.snapshot(selected)
	assert_eq(state["simulation_lod"]["mode"], "DORMANT")
	assert_eq(state["simulation_lod"]["placement"], "HOME")
	assert_false(actor.enabled)
	assert_true(actor.freeze)
	assert_eq(actor.collision_mask, 0)
	assert_eq(actor.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(
		(actor.get_component(C_NpcDecision) as C_NpcDecision).participation_generation,
		generation,
	)


func test_detached_perception_containers_cannot_mutate_live_owner() -> void:
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.rule_exposure[7] = 2.5
	awareness.warned_rules.append(7)
	var state: Dictionary[String, Variant] = GameplayDebuggerData.snapshot(actor)
	state["perception"]["rule_exposure"][7] = 900.0
	state["perception"]["warned_rules"].clear()
	state["decision"]["selection_reason"] = "forged"
	assert_eq(awareness.rule_exposure[7], 2.5)
	assert_eq(awareness.warned_rules, [7])
	assert_ne((actor.get_component(C_NpcDecision) as C_NpcDecision).selection_reason, &"forged")


func test_relationship_and_incoming_reservation_use_same_live_binding() -> void:
	var owner: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	var target: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[1].npc_id)
	var reservation: R_SmartObjectReservation = R_SmartObjectReservation.new()
	reservation.affordance_id = &"package_return"
	reservation.slot_id = &"return_slot"
	reservation.token = &"world/object/instance/1"
	owner.add_relationship(Relationship.new(reservation, target))
	var count: int = owner.relationships.size()
	var outgoing: Dictionary[String, Variant] = GameplayDebuggerData.snapshot(owner)
	var incoming: Dictionary[String, Variant] = GameplayDebuggerData.snapshot(target)
	assert_eq(outgoing["reservations"].size(), 1)
	assert_eq(incoming["reservations"].size(), 1)
	assert_eq(incoming["reservations"][0]["owner"], owner.id)
	assert_eq(incoming["reservations"][0]["token"], reservation.token)
	assert_eq(incoming["reservations"][0]["object"], "entity:" + target.id)
	incoming["reservations"][0]["token"] = "forged"
	assert_eq(reservation.token, &"world/object/instance/1")
	assert_eq(owner.relationships.size(), count)
	assert_false(_contains_object(outgoing))


func test_recent_events_are_selected_incoming_and_outgoing_bounded_snapshots() -> void:
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_BoundaryTrace.new())
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	var unrelated: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[1].npc_id)
	for index: int in BoundaryTrace.MAX_ENTRIES + 3:
		BoundaryTrace.record(
			&"qa.fixture",
			&"trace",
			BoundaryTraceEntry.Stage.COMPLETED,
			&"committed",
			actor.id,
			"",
		)
	BoundaryTrace.record(
		&"qa.unrelated",
		&"trace",
		BoundaryTraceEntry.Stage.COMPLETED,
		&"committed",
		unrelated.id,
		unrelated.id,
	)
	BoundaryTrace.record(
		&"qa.identity",
		&"trace",
		BoundaryTraceEntry.Stage.REJECTED,
		&"blocked",
		"",
		String(_district.people[0].npc_id),
	)
	var trace: C_BoundaryTrace = session.get_component(C_BoundaryTrace) as C_BoundaryTrace
	var sequence: int = trace.next_sequence
	var state: Dictionary[String, Variant] = GameplayDebuggerData.snapshot(actor)
	var events: Array[Dictionary] = state["recent_events"]
	assert_eq(events.size(), GameplayDebuggerData.RECENT_EVENT_LIMIT)
	assert_eq(events.back()["operation"], &"qa.identity")
	for event: Dictionary in events:
		assert_ne(event["operation"], &"qa.unrelated")
	events.back()["reason"] = "forged"
	assert_eq(trace.entries.back().reason, &"blocked")
	assert_eq(trace.next_sequence, sequence)
	assert_eq(trace.entries.size(), BoundaryTrace.MAX_ENTRIES)


func test_retired_selection_is_unavailable_even_if_object_still_exists() -> void:
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	_world.remove_entity(actor)
	assert_false(GameplayDebuggerData.available(actor))
	assert_eq(GameplayDebuggerData.snapshot(actor)["status"], "UNAVAILABLE")
	actor.free()
	assert_eq(GameplayDebuggerData.snapshot(actor)["status"], "UNAVAILABLE")
	assert_null(GameplayDebuggerData.resolve("entity:missing"))
#endregion


#region Native view lifecycle
func test_level_repair_is_visible_only_for_explicit_level_selection() -> void:
	var level: Node = Node.new()
	level.set_meta(&"persistent_world_id", &"level_before")
	add_child(level)
	var child: Node = Node.new()
	level.add_child(child)
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	var dock: VBoxContainer = AUTHORING_VIEW.instantiate() as VBoxContainer
	add_child(dock)
	var repair_level: Button = dock.get_node("%RepairLevel") as Button
	dock.call("bind_actor", actor, level)
	assert_false(repair_level.visible, "Entity selection cannot offer parent identity repair")
	dock.call("_repair_selected_level")
	assert_eq(level.get_meta(&"persistent_world_id"), &"level_before")
	dock.call("bind_actor", level, level)
	assert_true(repair_level.visible, "Explicit level selection offers level identity repair")
	dock.call("bind_actor", child, level)
	assert_false(repair_level.visible, "Ordinary descendants cannot repair the level either")
	dock.call("_repair_selected_level")
	assert_eq(level.get_meta(&"persistent_world_id"), &"level_before")
	dock.call("bind_actor", null, level)
	assert_false(repair_level.visible, "No selection does not implicitly select the level")
	dock.call("_repair_selected_level")
	assert_eq(level.get_meta(&"persistent_world_id"), &"level_before")
	dock.call("bind_actor", actor, actor)
	assert_false(repair_level.visible, "An Entity prefab root is not a level identity owner")
	dock.call("_repair_selected_level")
	assert_false(actor.has_meta(&"persistent_world_id"))
	dock.call("bind_actor", level, level)
	assert_true(repair_level.visible, "Returning to the level restores its action")
	dock.free()
	level.free()


func test_authoring_labels_follow_root_notifications_and_selection_without_editor_host() -> void:
	var level: Node = Node.new()
	level.set_meta(&"persistent_world_id", &"before_repair")
	add_child(level)
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	var other: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[1].npc_id)
	var dock: VBoxContainer = AUTHORING_VIEW.instantiate() as VBoxContainer
	add_child(dock)
	dock.call("bind_actor", actor, level)
	var level_label: Label = dock.get_node("%LevelId") as Label
	assert_eq(level_label.text, "Level ID: before_repair")
	level.set_meta(&"persistent_world_id", &"after_repair")
	level.notify_property_list_changed()
	assert_eq(level_label.text, "Level ID: after_repair")
	dock.call("bind_actor", other, level)
	assert_eq(level_label.text, "Level ID: after_repair")
	level.set_meta(&"persistent_world_id", &"before_repair")
	level.notify_property_list_changed()
	assert_eq(level_label.text, "Level ID: before_repair")
	dock.free()
	assert_false(level.property_list_changed.has_connections())
	level.free()


func test_authoring_dock_shows_null_recipe_and_keeps_trait_editing_in_inspector() -> void:
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	var dock: VBoxContainer = AUTHORING_VIEW.instantiate() as VBoxContainer
	add_child(dock)
	actor.component_resources.append(null)
	dock.call("bind_actor", actor, _world)
	dock.call("_set_advanced", true)
	assert_true((dock.get_node("%Recipes") as RichTextLabel).text.contains("missing_recipe"))
	assert_false((dock.get_node("%Configure") as Button).visible)
	assert_false((dock.get_node("%ResourceInspector") as Control).visible)
	actor.component_resources.pop_back()
	dock.free()


func test_native_layout_preserves_output_and_command_space_in_half_height_console() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	add_child(viewport)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.size = Vector2(640, 180)
	viewport.add_child(layout)
	var view: GameplayDebuggerView = VIEW.instantiate() as GameplayDebuggerView
	layout.theme = view.theme
	layout.add_child(view)
	view.inspect("entity:missing")
	var output: Panel = Panel.new()
	output.custom_minimum_size.y = 20.0
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(output)
	var input: LineEdit = LineEdit.new()
	input.add_theme_font_size_override("font_size", 14)
	layout.add_child(input)
	for frame: int in 3:
		await get_tree().process_frame
	assert_lte(layout.get_combined_minimum_size().y, 180.0)
	assert_lte(view.position.y + view.size.y, output.position.y)
	assert_lte(output.position.y + output.size.y, input.position.y)
	assert_lte(input.position.y + input.size.y, 180.0)
	assert_gte((view.get_node("%State") as Tree).size.y, 36.0)
	viewport.free()


func test_native_panel_refresh_revalidates_weak_selection_and_close_clears_rows() -> void:
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[0].npc_id)
	var view: GameplayDebuggerView = VIEW.instantiate() as GameplayDebuggerView
	Console.v_box_container.add_child(view)
	view.inspect("entity:" + actor.id)
	var status: Label = view.get_node("%Status") as Label
	assert_true(status.text.contains("REGISTERED"))
	_world.remove_entity(actor)
	actor.free()
	view.refresh()
	assert_true(status.text.contains("UNAVAILABLE"))
	view.close()
	assert_false(view.visible)
	assert_null((view.get_node("%State") as Tree).get_root())
	view.free()


func test_console_adapter_owns_panel_and_unregisters_command_on_teardown() -> void:
	var previous_theme: Theme = Console.v_box_container.theme
	var previous_input_menu: Theme = Console.line_edit.get_menu().theme
	var previous_output_menu: Theme = Console.rich_label.get_menu().theme
	var previous_font_size: int = Console.font_size
	var adapter: Node = load("res://content/debug/developer_console_debugger.gd").new()
	add_child(adapter)
	assert_true(Console.console_commands.has("debug_inspect"))
	Console.console_commands["debug_inspect"].function.call("entity:missing")
	var panel_node: Node = Console.v_box_container.get_node("GameplayDebugger")
	var panel: GameplayDebuggerView = panel_node as GameplayDebuggerView
	assert_true(panel.visible)
	assert_eq((panel.get_node("%Select") as Button).get_theme_font_size("font_size"), 14)
	assert_eq(Console.line_edit.get_menu().get_theme_font_size("font_size"), 14)
	assert_eq(Console.rich_label.get_menu().get_theme_font_size("font_size"), 14)
	assert_eq(Console.font_size, 14)
	var background: PanelContainer = panel.get_node("%Background") as PanelContainer
	assert_eq((background.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a, 1.0)
	Console.console_closed.emit()
	assert_false(panel.visible)
	adapter.free()
	assert_false(Console.console_commands.has("debug_inspect"))
	assert_null(Console.v_box_container.get_node_or_null("GameplayDebugger"))
	assert_same(Console.v_box_container.theme, previous_theme)
	assert_same(Console.line_edit.get_menu().theme, previous_input_menu)
	assert_same(Console.rich_label.get_menu().theme, previous_output_menu)
	assert_eq(Console.font_size, previous_font_size)
#endregion


#region Detached-value assertion
func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _contains_object(key) or _contains_object(value[key]):
				return true
	elif value is Array:
		for item: Variant in value:
			if _contains_object(item):
				return true
	return false
#endregion
