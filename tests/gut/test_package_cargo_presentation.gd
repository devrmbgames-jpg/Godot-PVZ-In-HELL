extends GutTest
## Real parcel history, stickers, terminal icons/detail and archive agree with committed cargo.

const ITEMS_ROOT: String = "res://content/domains/inventory/definitions/"
const SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)
const LINE: PackedScene = preload("res://content/ui/ui_terminal_package_line.tscn")
const DETAIL: PackedScene = preload("res://content/ui/ui_terminal_package_detail_info.tscn")
const HUD: PackedScene = preload("res://content/ui/interaction_hud.tscn")

var _world: World


#region Native fixture lifetime
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_PackageLedger.new(), C_LootDrops.new()]
	_world.add_entity(session)


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _item(key: String) -> DEF_InventoryItem:
	return load(ITEMS_ROOT + "def_item_" + key + ".tres") as DEF_InventoryItem


func _legacy(key: StringName) -> DEF_Package:
	for definition: DEF_Package in SUPPLY.packages:
		if definition.key == key:
			return definition
	return null


func _package(key: String, quantity: int, legacy_key: StringName = &"bottles") -> E_Package:
	var item: DEF_InventoryItem = _item(key)
	var package_id: String = "presentation/" + key + "/" + str(quantity)
	var shipment: PackageShipmentPlan = PackageShipmentRules.for_quantity(
		item,
		quantity,
		SUPPLY.packing_profiles,
		7,
		package_id,
		1,
	)
	assert_not_null(shipment)
	if shipment == null:
		return null
	var parcel: E_Package = (load(shipment.scene_path()) as PackedScene).instantiate() as E_Package
	assert_true(
		ReceivingPackageFactory.configure_recipe(parcel, _legacy(legacy_key), package_id, shipment)
	)
	(parcel as Node as RigidBody3D).freeze = true
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		parcel,
		_world,
		GECSIO.uuid(),
	)
	context.initial_fields[C_PackageContents as Script] = shipment.contents_fields()
	var registered: bool = EntityCompositionService.try_register(context)
	assert_true(registered)
	if not registered:
		parcel.free()
		return null
	assert_not_null(PackageHistoryService.record_arrival(parcel, 1))
	return parcel


func _record(parcel: E_Package) -> PackageRegistrationRecord:
	return PackageHistoryService.record_for(parcel.package_id)


func _line(record: PackageRegistrationRecord) -> UI_TerminalButtonPackage:
	var line: UI_TerminalButtonPackage = LINE.instantiate() as UI_TerminalButtonPackage
	add_child_autofree(line)
	line.present(record, null, null, false)
	return line


func _sticker_text(parcel: E_Package) -> String:
	var condition: PackageConditionView = parcel.get_node("Condition") as PackageConditionView
	condition.call("_process", 0.0)
	var stickers: Array[Label3D] = condition.get("_stickers") as Array[Label3D]
	assert_eq(stickers.size(), 4)
	return stickers[0].text if not stickers.is_empty() else ""
#endregion


#region Actual cargo across native views
func test_solid_artifact_replaces_legacy_liquid_heavy_fragile_marks_and_history() -> void:
	var parcel: E_Package = _package("holy_artifact", 1)
	var record: PackageRegistrationRecord = _record(parcel)
	await get_tree().process_frame
	var tags: int = PackageOrderPresentation.tags(record)
	assert_eq(tags, DEF_Package.Tag.NORMAL)
	assert_almost_eq(PackageOrderPresentation.mass_kg(record), 1.3, 0.0001)
	var history: PackageHistoryId = PackageHistoryId.parse(record.history_id)
	assert_eq(history.hazard_class, DEF_Package.HazardClass.NORMAL)
	assert_eq(history.mass_tenths_kg, 13)
	var marking: String = _sticker_text(parcel)
	assert_false("ЖИДКОСТЬ" in marking)
	assert_false("ХРУПКОЕ" in marking)
	assert_false("ТЯЖЁЛОЕ" in marking)
	var line: UI_TerminalButtonPackage = _line(record)
	for path: String in ["%IconFluid", "%IconWeight", "%IconFragile", "%IconToxic", "%IconAnomaly"]:
		assert_false((line.get_node(path) as Control).visible, path)
	var hud: CanvasLayer = autofree(HUD.instantiate()) as CanvasLayer
	var debug_text: String = hud.call("_package_debug_text", parcel, parcel.package_definition)
	assert_false("Жидкость" in debug_text)
	assert_true("HAZARD DAMAGE: Нет" in debug_text)
	assert_true("HAZARD DESTROYED: Нет" in debug_text)


func test_bulk_title_weight_detail_sort_and_native_size_follow_actual_composition() -> void:
	var bulk: E_Package = _package("toy_block", 8, &"books")
	var artifact: E_Package = _package("holy_artifact", 1)
	var record: PackageRegistrationRecord = _record(bulk)
	assert_eq(record.ordered_quantity, 8)
	assert_true("×8" in PackageOrderPresentation.title(record))
	assert_almost_eq(PackageOrderPresentation.mass_kg(record), 6.0, 0.0001)
	assert_eq(
		PackageHistoryId.parse(record.history_id).size_class,
		PackageHistoryId.SizeClass.LARGE,
	)
	var detail: UI_TerminalPackageDetailInfo = DETAIL.instantiate() as UI_TerminalPackageDetailInfo
	add_child_autofree(detail)
	detail.present(record, null, null)
	assert_true("×8" in (detail.get_node("%LabelName") as Label).text)
	assert_true(
		"Вес: 6.0 кг" in (detail.get_node("%RichTextLabelDescription") as RichTextLabel).text
	)
	var panel: TerminalPanel = autofree(TerminalPanel.new()) as TerminalPanel
	panel.set("_sort_mode", TerminalPanel.SortMode.WEIGHT)
	assert_gt(int(panel.call("_compare_records", record, _record(artifact))), 0)
	var scythe: E_Package = _package("scythe", 1, &"books")
	assert_eq(
		PackageHistoryId.parse(_record(scythe).history_id).size_class,
		PackageHistoryId.SizeClass.OVERSIZED,
	)


func test_acid_fire_and_blood_keep_independent_native_icons_and_liquid_marks() -> void:
	for key: String in ["acid_barrel", "fire_flask", "blood_flask"]:
		var parcel: E_Package = _package(key, 1, &"books")
		var record: PackageRegistrationRecord = _record(parcel)
		await get_tree().process_frame
		var line: UI_TerminalButtonPackage = _line(record)
		assert_true((line.get_node("%IconFluid") as Control).visible, key)
		assert_true("ЖИДКОСТЬ" in _sticker_text(parcel), key)
		assert_eq((line.get_node("%IconToxic") as Control).visible, key == "acid_barrel")
		assert_eq((line.get_node("%IconFire") as Control).visible, key == "fire_flask")
		assert_eq((line.get_node("%IconWeight") as Control).visible, key == "acid_barrel")
		assert_eq((line.get_node("%IconFragile") as Control).visible, key != "acid_barrel")
		var history: PackageHistoryId = PackageHistoryId.parse(record.history_id)
		assert_eq(history.hazard_class, PackageOrderPresentation.hazard_class(record))
		assert_eq(history.mass_tenths_kg, roundi(PackageOrderPresentation.mass_kg(record) * 10.0))


func test_consumption_and_body_departure_preserve_arrival_composition_and_archive_weight() -> void:
	var parcel: E_Package = _package("blood_flask", 1, &"books")
	var record: PackageRegistrationRecord = _record(parcel)
	var original_id: String = record.history_id
	var original_mass: float = PackageOrderPresentation.mass_kg(record)
	await get_tree().process_frame
	assert_not_null(PackageContentsService.consume_catalog_rupture(parcel))
	assert_eq(PackageContentsService.handling_tags(parcel), 0)
	assert_false("ЖИДКОСТЬ" in _sticker_text(parcel))
	assert_true(bool(PackageOrderPresentation.tags(record) & DEF_Package.Tag.LIQUID))
	assert_eq(PackageOrderPresentation.mass_kg(record), original_mass)
	assert_almost_eq((parcel as Node as RigidBody3D).mass, 0.7, 0.0001)
	_world.remove_entity(parcel)
	assert_same(PackageHistoryService.record_for(record.package_id), record)
	assert_eq(record.history_id, original_id)
	var decoded: PackageRegistrationRecord = (
		SaveDataCodec.decode(SaveDataCodec.encode(record)) as PackageRegistrationRecord
	)
	assert_not_null(decoded)
	assert_eq(decoded.ordered_quantity, 1)
	assert_same(decoded.packing_profile, record.packing_profile)
	assert_eq(PackageOrderPresentation.mass_kg(decoded), original_mass)
	assert_true(bool(PackageOrderPresentation.tags(decoded) & DEF_Package.Tag.LIQUID))


func test_multiple_hazard_flags_survive_the_single_diagnostic_id_class() -> void:
	var item: DEF_InventoryItem = _item("reagent_flask").duplicate() as DEF_InventoryItem
	item.cargo_profile = item.cargo_profile.duplicate() as DEF_ItemCargo
	item.cargo_profile.hazards = (
		DEF_ItemCargo.Hazard.TOXIC | DEF_ItemCargo.Hazard.FLAMMABLE | DEF_ItemCargo.Hazard.EXPLOSIVE
	)
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.definition = _legacy(&"books")
	record.ordered_item = item
	record.ordered_quantity = 1
	record.packing_profile = SUPPLY.packing_profiles[1]
	var line: UI_TerminalButtonPackage = _line(record)
	assert_eq(PackageOrderPresentation.hazard_class(record), DEF_Package.HazardClass.EXPLOSIVE)
	assert_true((line.get_node("%IconExplotion") as Control).visible)
	assert_true((line.get_node("%IconToxic") as Control).visible)
	assert_true((line.get_node("%IconFire") as Control).visible)
#endregion
