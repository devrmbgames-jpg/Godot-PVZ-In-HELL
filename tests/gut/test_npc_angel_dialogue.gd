extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Native angel signs expose requests in the world without dialogue panels or modal capture.

const ANGEL_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_weeping_angel.tres"
)
const PACKAGE_SCENE: String = "res://content/domains/packages/entities/package_a.tscn"
const SERVICE_TREE: String = "res://content/domains/customers/ai/trees/bt_npc_service.tres"


#region Native sign fixture
func _angel_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = ANGEL_PROFILE
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person


func _sign(body: E_DistrictNpc) -> NpcSignboard:
	return body.get_node("Signboard") as NpcSignboard


func _writing(body: E_DistrictNpc) -> Label3D:
	return _sign(body).get_node("Text") as Label3D


func _freeze(body: E_DistrictNpc, person: NpcRecord) -> void:
	var constraint: C_NpcGazeFreeze = body.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
	constraint.rule = NpcGazeQueries.selected_rule(person.rules_for())
	assert_not_null(constraint.rule)
	constraint.observed = true
	body.sync_gaze_constraint()
	assert_true(NpcGazeQueries.frozen(body))
	assert_true(body.freeze)


func _unregistered(person: NpcRecord) -> CustomerVisit:
	var visit: CustomerVisit = _case(person, "angel_unregistered")
	visit.definition = DEF_Customer.new()
	var prefab: PackedScene = load(PACKAGE_SCENE) as PackedScene
	var parcel: E_Package = prefab.instantiate() as E_Package
	parcel.package_id = visit.package_id
	var schedule: DEF_CustomerSchedule = (
		load(DEF_CUSTOMER_SCHEDULE_DEFAULT_PATH) as DEF_CustomerSchedule
	)
	parcel.package_definition = schedule.supply.packages[0]
	EntityCompositionFixture.register(_world, parcel)
	assert_true(EntityAvailability.contains(parcel, _world))
	return visit


func _prepare_role(body: E_DistrictNpc, person: NpcRecord, visit: CustomerVisit) -> void:
	assert_true(NpcServiceRole.begin(body, person, visit, 1))
	var role: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	role.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
#endregion


#region World visibility and read-only projections
func test_authored_board_and_label_follow_frozen_angel_without_modal_input() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	var sign: NpcSignboard = _sign(body)
	var board: MeshInstance3D = sign.get_node("Board") as MeshInstance3D
	assert_not_null(board.mesh)
	assert_true(board.mesh is BoxMesh)
	assert_eq(sign.scene_file_path, "res://content/domains/npc/presentation/npc_signboard.tscn")
	assert_lt(sign.position.z, 0.0)
	assert_gt(sign.position.y, 1.0)
	var native_pose: Transform3D = body.global_transform
	var prior_focus: int = InteractionControlFocus.current(_player)
	var prior_mouse: Input.MouseMode = Input.mouse_mode
	var snapshot: Dictionary = SaveDataCodec.encode(person) as Dictionary
	_freeze(body, person)
	for frame: int in range(3):
		await get_tree().process_frame
	assert_true(sign.visible)
	assert_string_contains(_writing(body).text, "НЕ ОТВОДИ ВЗГЛЯД")
	assert_string_contains(_writing(body).text, "\n")
	assert_false(_writing(body).no_depth_test)
	assert_false((body.get_node("Message") as Label3D).visible)
	assert_eq(body.global_transform, native_pose)
	assert_eq(InteractionControlFocus.current(_player), prior_focus)
	assert_eq(Input.mouse_mode, prior_mouse)
	assert_eq(SaveDataCodec.encode(person), snapshot)
	assert_true(get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP).is_empty())
	assert_false(NpcDialogueService.request_open(_player, body))


func test_registration_refreshes_same_physical_sign_and_service_uses_no_panel() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	var visit: CustomerVisit = _unregistered(person)
	_prepare_role(body, person, visit)
	_freeze(body, person)
	await get_tree().process_frame
	assert_string_contains(_writing(body).text, "НОМЕРА НЕТ")
	var sign: NpcSignboard = _sign(body)
	var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
	assert_eq(
		PackageRegistrationService.register_package(parcel).outcome,
		PackageScanResult.Outcome.REGISTERED,
	)
	var number: int = CustomerPresentation.registered_number(visit)
	assert_gt(number, 0)
	assert_true(_run_tree(body, SERVICE_TREE, 0.2))
	await get_tree().process_frame
	assert_same(_sign(body), sign)
	assert_string_contains(_writing(body).text, "%03d" % number)
	assert_string_contains(_writing(body).text, "НЕ ВСКРЫВАТЬ")
	assert_false(CustomerDialogueService.request_open(_player, body))
	assert_true(get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP).is_empty())
	assert_null(NpcDialogueService.participant(body))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.player_denial_count, 0)


func test_written_personal_offer_accepts_through_native_action_without_dialogue() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	var visit: CustomerVisit = _delivery_case(person, "angel_world_delivery")
	var job: NpcHomeDelivery = HomeDeliveryQueries.personal_for(person.npc_id, visit.visit_id)
	assert_not_null(job)
	await get_tree().process_frame
	assert_string_contains(_writing(body).text, "ДОСТАВИТЬ ДОМОЙ")
	assert_string_contains(_writing(body).text, NpcPopulationQueries.place_name(job.address_id))
	var action: DEF_CustomerAction = load(
		"res://content/domains/customers/definitions/def_action_customer_request.tres"
	) as DEF_CustomerAction
	var authored_caption: String = action.caption
	assert_string_contains(action.caption_for(_player, body, body), "Согласиться")
	assert_true(action.is_available(_player, body, body))
	assert_true(action.complete(_player, body, body))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_eq(person.goal_id, person.home_id)
	assert_false(action.complete(_player, body, body))
	assert_eq(_district.home_deliveries.size(), 1)
	assert_eq(action.caption, authored_caption)
	assert_eq(WalletService.current().operations.size(), 0)
	assert_true(get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP).is_empty())
	assert_null(NpcDialogueService.participant(body))


func test_role_cleanup_death_and_scene_owner_release_do_not_leave_stale_sign() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	var visit: CustomerVisit = _delivery_case(person, "angel_world_cleanup")
	_prepare_role(body, person, visit)
	await get_tree().process_frame
	assert_string_contains(_writing(body).text, "ЗАКАЗ")
	NpcServiceRole.release(body, visit.visit_id)
	await get_tree().process_frame
	assert_false(_writing(body).text.contains("ЗАКАЗ"))
	body.add_component(C_Death.new())
	assert_false(_sign(body).visible)
	assert_eq(_writing(body).text, "")
	var sign_reference: WeakRef = weakref(_sign(body))
	_world.remove_entity(body)
	await get_tree().process_frame
	assert_null(sign_reference.get_ref())


func test_ordinary_actor_restores_native_message_and_keeps_modal_conversation() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	await get_tree().process_frame
	assert_true(_sign(body).visible)
	person.profile = load(LOST_PATH) as DEF_NpcArchetype
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	await get_tree().process_frame
	assert_false(_sign(body).visible)
	assert_true((body.get_node("Message") as Label3D).visible)
	assert_true(DialoguePanelRouter.open_street(_player, body))
	var panels: Array[Node] = get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP)
	assert_eq(panels.size(), 1)
	var panel: CustomerDialoguePanel = panels[0] as CustomerDialoguePanel
	assert_true((panel.get("_speaker") as Label).visible)
	assert_true((panel.get("_text") as RichTextLabel).visible)
	panel.close_dialogue()
	assert_ne(InteractionControlFocus.current(_player), InteractionControlFocus.Priority.MODAL)


func test_variant_selection_and_sign_query_do_not_change_durable_person() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	assert_eq(person.profile.dialogue_variants.size(), 2)
	var snapshot: Dictionary = SaveDataCodec.encode(person) as Dictionary
	for repeat: int in range(3):
		assert_true(NpcDialogueService.uses_signboard(body))
		assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
		NpcCustomerComposition.install(_world)
		await get_tree().process_frame
	assert_eq(_sign(body).text_requested.get_connections().size(), 1)
	assert_eq(SaveDataCodec.encode(person), snapshot)
	var copy: NpcRecord = SaveDataCodec.decode(snapshot) as NpcRecord
	assert_eq(copy.variation.dialogue_path, person.variation.dialogue_path)
	assert_eq(copy.display_name, person.display_name)
#endregion
