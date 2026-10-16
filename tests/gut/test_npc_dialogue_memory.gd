extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Реальные street/service ctx, compiled mutations и disk preflight постоянной личности.


class WaitingStreetContext extends NpcStreetDialogueContext:
	signal resume_step
	var entered: bool = false


	func wait_step() -> void:
		entered = true
		await resume_step


#region Пять операций и жизненный цикл
func test_runtime_object_value_keeps_identity_until_explicit_replacement() -> void:
	var person: NpcRecord = _lost_person()
	var street: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, _stage(person))
	assert_true(street.begin())
	var node: Node = Node.new()
	street.set_val(&"runtime", node)
	assert_same(street.get_val(&"runtime"), node)
	street.set_val(&"runtime", null)
	assert_true(person.dialogue_values.has(&"runtime"))
	node.free()
	street.end()


func test_reads_and_separate_namespaces_do_not_allocate_keys_or_people() -> void:
	var person: NpcRecord = _lost_person()
	var street: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, _stage(person))
	assert_true(street.begin())
	var before: Dictionary = WorldSnapshotService.capture(_root, 1)
	for repeat: int in 3:
		assert_false(street.get_tag(&"missing"))
		assert_null(street.get_val(&"missing"))
	assert_eq(WorldSnapshotService.capture(_root, 1), before)
	street.set_tag(&"shared")
	street.set_tag(&"shared")
	street.set_val(&"shared", null)
	assert_true(street.get_tag(&"shared"))
	assert_null(street.get_val(&"shared"))
	assert_true(person.dialogue_values.has(&"shared"))
	assert_eq(person.dialogue_tags.size(), 1)
	assert_eq(person.dialogue_values.size(), 1)
	street.end()


func test_numeric_addition_preserves_types_and_reports_rejection_without_mutation() -> void:
	var person: NpcRecord = _lost_person()
	assert_eq(NpcDialogueMemoryService.add_val(person, &"count", 3), "")
	assert_eq(typeof(person.dialogue_values[&"count"]), TYPE_INT)
	assert_eq(NpcDialogueMemoryService.add_val(person, &"count", -1), "")
	assert_eq(person.dialogue_values[&"count"], 2)
	assert_eq(NpcDialogueMemoryService.add_val(person, &"count", 0.5), "")
	assert_eq(typeof(person.dialogue_values[&"count"]), TYPE_FLOAT)
	assert_eq(person.dialogue_values[&"count"], 2.5)
	for invalid: Variant in [true, "3", null, [], { }]:
		var before: Dictionary = person.dialogue_values.duplicate(true)
		var diagnostic: String = NpcDialogueMemoryService.add_val(person, &"count", invalid)
		assert_string_contains(diagnostic, "count")
		assert_string_contains(diagnostic, "int/float")
		assert_eq(person.dialogue_values, before)
	for invalid: Variant in [true, "3", null, [], { }]:
		NpcDialogueMemoryService.set_val(person, &"invalid", invalid)
		assert_false(NpcDialogueMemoryService.add_val(person, &"invalid", 1).is_empty())
		assert_eq(person.dialogue_values[&"invalid"], invalid)


func test_street_service_and_next_day_share_one_person_but_not_another_npc() -> void:
	var person: NpcRecord = _lost_person()
	var body: E_DistrictNpc = _stage(person)
	var street: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(street.begin())
	var grudge: bool = street.holds_grudge()
	street.set_tag(&"holds_grudge")
	assert_eq(street.holds_grudge(), grudge)
	street.set_tag(&"visited")
	street.set_val(&"compound", { "type": [1, true, null], "definition": "literal" })
	street.add_val(&"count", 1)
	street.end()
	street.set_val(&"compound", "late")
	street.add_val(&"count", 100)
	street.set_tag(&"late")
	var visit: CustomerVisit = _case(person, "memory")
	var service: CustomerDialogueContext = _service_context(body, visit)
	assert_true(service.get_tag(&"visited"))
	assert_false(service.get_tag(&"late"))
	assert_eq(service.get_val(&"count"), 1)
	assert_eq(service.get_val(&"compound"), { "type": [1, true, null], "definition": "literal" })
	service.add_val(&"count", 1)
	service.end()
	NpcServiceRole.release(body, visit.visit_id)
	var other: NpcRecord = _district.people[1]
	assert_true(other.dialogue_tags.is_empty())
	assert_true(other.dialogue_values.is_empty())
	DistrictPopulationService.prepare_morning(2)
	body = _stage(person)
	var reopened: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(reopened.begin())
	assert_eq(reopened.get_val(&"count"), 2)
	reopened.invalidate()
	reopened.set_tag(&"late")
	reopened.set_val(&"count", 0)
	reopened.add_val(&"count", 100)
	assert_eq(person.dialogue_values[&"count"], 2)
	assert_false(person.dialogue_tags.has(&"late"))


func test_author_example_first_repeat_and_confirmed_gift_accounting() -> void:
	var text: String = FileAccess.get_file_as_string("res://docs/dialogue_memory.md")
	var source: String = text.get_slice("```dialogue\n", 1).get_slice("```", 0)
	assert_false(source.is_empty())
	var compiled: DMCompilerResult = DMCompiler.compile_string(source, "")
	assert_eq(compiled.errors.size(), 0)
	if not compiled.errors.is_empty():
		return
	var resource: DialogueResource = (
		DialogueManager.create_resource_from_text(source) as DialogueResource
	)
	_dialogue_resources.append(resource)
	var person: NpcRecord = _lost_person()
	var street: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, _stage(person))
	assert_true(street.begin())
	assert_string_contains((await _line(resource, street, "greeting")).text, "новичок")
	assert_string_contains((await _line(resource, street, "greeting")).text, "это ты")
	assert_string_contains((await _line(resource, street, "optional_counter")).text, "не считали")
	assert_false(person.dialogue_values.has(&"optional_count"))
	# This fixture starts after a documented confirmed transfer; it does not perform payment.
	street.set_val(&"taked_money", 300)
	assert_string_contains((await _line(resource, street, "remember_gift")).text, "спонсор")
	assert_eq(street.get_val(&"taked_money"), 310)
	assert_not_null(await _line(resource, street, "remember_gift"))
	assert_eq(street.get_val(&"taked_money"), 320, "new deliberate entry adds again")
	street.end()


func test_panel_rejects_duplicate_advance_and_closed_late_mutation() -> void:
	var source: String = (
		"~ count\n$> ctx.wait_step()\n$> ctx.add_val(\"steps\", 1)\n" + "NPC: Done.\n=> END"
	)
	var resource: DialogueResource = (
		DialogueManager.create_resource_from_text(source) as DialogueResource
	)
	_dialogue_resources.append(resource)
	var person: NpcRecord = _lost_person()
	var street: WaitingStreetContext = WaitingStreetContext.new(_player, _stage(person))
	assert_true(street.begin())
	var panel: CustomerDialoguePanel = CustomerDialoguePanel.new()
	_root.add_child(panel)
	assert_true(panel.open_for(_player, street, resource, "count"))
	assert_true(street.entered)
	panel.call("_advance", "count")
	street.resume_step.emit()
	for frame: int in 8:
		if not bool(panel.get("_advancing")):
			break
		await get_tree().process_frame
	assert_eq(street.get_val(&"steps"), 1)
	street.entered = false
	panel.call("_advance", "count")
	assert_true(street.entered)
	panel.close_dialogue()
	street.resume_step.emit()
	await get_tree().process_frame
	assert_eq(person.dialogue_values[&"steps"], 1)
	DialogueResourceLifecycle.release_runtime_references(resource)
#endregion
