extends GutTest


func test_package_line_status_tracks_only_terminal_declarations() -> void:
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = "package/test"
	record.number = 7
	record.active = true
	var state: C_PackageState = C_PackageState.new()
	state.registration = C_PackageState.Registration.REGISTERED
	var visit: CustomerVisit = CustomerVisit.new()
	visit.started = true

	assert_eq(UI_TerminalButtonPackage.status_text(record, state, visit), "БЕЗ ОТМЕТКИ")
	visit.declaration = CustomerVisit.Declaration.TAKEN
	assert_eq(UI_TerminalButtonPackage.status_text(record, state, visit), "ЗАБРАЛИ")
	visit.declaration = CustomerVisit.Declaration.REFUSED
	assert_eq(UI_TerminalButtonPackage.status_text(record, state, visit), "ОТКАЗАЛИСЬ")
	visit.declaration = CustomerVisit.Declaration.LOST
	assert_eq(UI_TerminalButtonPackage.status_text(record, state, visit), "ПОТЕРЯНА")


func test_archive_follows_declaration_not_physical_departure_for_customer_visit() -> void:
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = "package/test"
	record.active = false
	record.departure = C_PackageState.Registration.DELIVERED
	var visit: CustomerVisit = CustomerVisit.new()

	assert_false(TerminalPanel._is_archived(record, visit))
	visit.declaration = CustomerVisit.Declaration.TAKEN
	assert_true(TerminalPanel._is_archived(record, visit))
	assert_false(TerminalPanel._is_archived(record, null), "Unreported physical departure cannot hide the record")
	assert_true(TerminalPanel._is_archived(record, null, true))


func test_hidden_truth_does_not_change_normal_status_or_search_but_debug_can_show_it() -> void:
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.number = 7
	record.active = true
	var state: C_PackageState = C_PackageState.new()
	state.damage = C_PackageState.Damage.DAMAGED
	state.opening = C_PackageState.Opening.OPENED
	var visit: CustomerVisit = CustomerVisit.new()
	assert_eq(UI_TerminalButtonPackage.status_text(record, state, visit), "БЕЗ ОТМЕТКИ")
	assert_true("ПОВРЕЖДЕНА" in UI_TerminalButtonPackage.status_text(record, state, visit, true))
	var panel: TerminalPanel = TerminalPanel.new()
	assert_false(panel.debug_package_status_enabled)
	assert_false(panel._matches_search(record, state, visit, "повреждена"))
	panel.debug_package_status_enabled = true
	assert_true(panel._matches_search(record, state, visit, "повреждена"))
	visit.actual = CustomerVisit.Actual.DELIVERED
	assert_eq(UI_TerminalButtonPackage.status_text(record, null, visit), "БЕЗ ОТМЕТКИ")
	assert_eq(UI_TerminalButtonPackage.status_text(record, null, visit, true), "ВЫДАНА · НЕ ОТМЕЧЕНА")
	panel.free()


func test_real_terminal_detail_only_reveals_condition_when_opted_into_debug() -> void:
	var packed: PackedScene = load("res://content/ui/ui_terminal_package_detail_info.tscn") as PackedScene
	var detail: UI_TerminalPackageDetailInfo = packed.instantiate() as UI_TerminalPackageDetailInfo
	add_child(detail)
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.number = 7
	record.definition = DEF_Package.new()
	var state: C_PackageState = C_PackageState.new()
	state.damage = C_PackageState.Damage.DAMAGED
	state.leaking = true
	var description: RichTextLabel = detail.get_node("%RichTextLabelDescription") as RichTextLabel
	detail.present(record, state, null)
	assert_false("повреждена" in description.text)
	assert_false("протекает" in description.text)
	detail.present(record, state, null, true)
	assert_true("повреждена" in description.text)
	assert_true("протекает" in description.text)
	detail.free()


func test_package_line_exposes_only_three_terminal_outcome_signals() -> void:
	var line: UI_TerminalButtonPackage = UI_TerminalButtonPackage.new()
	assert_true(line.has_signal("taken_requested"))
	assert_true(line.has_signal("refused_requested"))
	assert_true(line.has_signal("lost_requested"))
	assert_false(line.has_signal("deny_requested"))
	assert_false(line.has_signal("buyout_requested"))
	assert_false(line.has_signal("return_requested"))
	line.free()


func test_new_terminal_support_classes_compile_without_scene_assets() -> void:
	var detail: UI_TerminalPackageDetailInfo = UI_TerminalPackageDetailInfo.new()
	var history: UI_TerminalLogHistory = UI_TerminalLogHistory.new()
	assert_not_null(detail)
	assert_not_null(history)
	detail.free()
	history.free()


func test_registration_history_id_is_durable_record_data() -> void:
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = "package/test"
	record.history_id = "3-02-TL08C"
	assert_eq(record.history_id, "3-02-TL08C")
