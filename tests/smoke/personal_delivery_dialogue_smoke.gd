extends Node
## Два процесса проверяют личный диалог, перезапуск полного района и однократную засаду в дереве.

const SAVE_PATH: String = "user://personal_delivery_dialogue_smoke.pvzh"
const MAX_RECEIVING_FRAMES: int = 900
const EXPECTED_BATCH_SIZE: int = 5
const TREE_PATH: String = "res://content/ai/trees/bt_district_npc.tres"

var _failed: bool = false

#region Реальный район и сохранение
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup_slot()
	var level: Node3D = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	level.set("autosave_path", "")
	add_child(level)
	if restoring:
		var saved: Dictionary = AutosaveStore.read(SAVE_PATH)
		_check(WorldSnapshotService.valid(saved, level), "saved full world is valid")
		_check(WorldSnapshotService.restore(saved, level), "full world restored in new process")
	else:
		for frame: int in MAX_RECEIVING_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowService.current().visits.size() == EXPECTED_BATCH_SIZE:
				break
		_check(CustomerFlowService.current().visits.size() == EXPECTED_BATCH_SIZE, "real morning batch received")
	level.set_physics_process(false)
	if _failed:
		get_tree().quit(1)
		return

	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	var district: C_District = DistrictPopulationService.current()
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	if not restoring:
		district.definition = district.definition.duplicate() as DEF_District
		district.definition.personal_delivery_probability = 0.0
		district.definition.delivery_bargain_probability = 1.0
		district.definition.force_personal_delivery_scenario = true
		district.delivery_offer_day = 0
		district.terminal_offer_target = 0
		district.delivery_considered.clear()
		for visit: CustomerVisit in CustomerFlowService.current().visits:
			var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
			_check(parcel != null and PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED, "real box registered")

	var job: NpcHomeDelivery = _personal_job(district)
	_check(job != null, "personal delivery exists")
	if job == null:
		get_tree().quit(1)
		return
	_check(job.scenario_id == district.definition.personal_delivery_scenario.key and not job.published, "authored scenario remains private")
	if restoring:
		await _ambush(job, player)
	else:
		await _negotiate_and_accept(job, player)

	district.definition = load("res://content/definitions/gameplay/npc/def_district_default.tres") as DEF_District
	var snapshot: Dictionary = WorldSnapshotService.capture(level, 1)
	_check(WorldSnapshotService.valid(snapshot, level), "complete district snapshot remains valid")
	if restoring:
		_check(WorldSnapshotService.restore(snapshot, level), "ambush outcome restores without replay")
		job = NpcDeliveryOfferService.find(job.job_id)
		_check(job != null and job.status == NpcHomeDelivery.Status.AMBUSHED, "ambush remains terminal after restore")
		NpcHomeDeliveryService.finish_evening(1)
		_check(WalletService.current().operations.is_empty(), "restored scenario grants no money or fine")
		_cleanup_slot()
	else:
		_check(AutosaveStore.write(snapshot, SAVE_PATH) == OK, "private negotiated job saved")
	print("Personal delivery dialogue smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)
#endregion

#region Настоящий диалог и LimboAI
func _negotiate_and_accept(job: NpcHomeDelivery, player: Entity) -> void:
	var body: E_DistrictNpc = DistrictPopulationService.body_for(job.npc_id)
	var person: NpcRecord = DistrictPopulationService.person_for(job.npc_id)
	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	NpcServiceRole.begin(body, person, visit, 1)
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var context: CustomerDialogueContext = CustomerDialogueContext.new(player, body)
	_check(context.begin(), "real service conversation begins")
	var resource: DialogueResource = load(CustomerDialogueService.DIALOGUE_PATH) as DialogueResource
	var prompt: DialogueLine = await _prompt(resource, context, "home_request")
	_check(prompt != null and prompt.responses.size() == 3, "offer exposes accept, bargain and refuse")
	if prompt != null and prompt.responses.size() == 3:
		prompt = await _prompt(resource, context, (prompt.responses[1] as DialogueResponse).next_id)
		_check(job.bargain == NpcHomeDelivery.Bargain.ACCEPTED and job.bonus == floori(job.base_bonus * 1.5), "dialogue commits one +50% bargain")
		var end_line: DialogueLine = await resource.get_next_dialogue_line((prompt.responses[0] as DialogueResponse).next_id, [{"ctx": context}])
		_check(end_line == null and job.status == NpcHomeDelivery.Status.ACCEPTED, "dialogue accepts actual delivery")
	context.end()
	DialogueResourceLifecycle.release_runtime_references(resource)
	_check(CustomerFlowService.parcel_for(job.package_id) != null and WalletService.current().operations.is_empty(), "offer does not move box or grant money")

func _ambush(job: NpcHomeDelivery, player: Entity) -> void:
	_check(job.status == NpcHomeDelivery.Status.ACCEPTED and job.bargain == NpcHomeDelivery.Bargain.ACCEPTED and job.bonus == floori(job.base_bonus * 1.5), "accepted price and bargain survive restart")
	var body: E_DistrictNpc = DistrictPopulationService.body_for(job.npc_id)
	var person: NpcRecord = DistrictPopulationService.person_for(job.npc_id)
	var door: Entity = _door(job.address_id)
	_check(door != null and NpcHomeDeliveryService.knock(player, door), "same NPC responds at authored home")
	body.place_at(DistrictPopulationService.position_for(job.address_id))
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	await get_tree().physics_frame
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.player_visible = NpcPerceptionService.can_see(body, player, person.profile)
	_check(awareness.player_visible, "physical sight recognizes player at home")
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var context: CustomerDialogueContext = CustomerDialogueContext.new(player, body)
	_check(context.begin(), "home conversation begins")
	var resource: DialogueResource = load(CustomerDialogueService.DIALOGUE_PATH) as DialogueResource
	var panel: CustomerDialoguePanel = CustomerDialoguePanel.new()
	add_child(panel)
	_check(panel.open_for(player, context, resource, "direct"), "dialogue captures player input")
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	_check(runner.behavior_tree.resource_path == TREE_PATH, "production tree installed")
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	decision.intent_owner = C_NpcDecision.Owner.NONE
	_check(NpcBrainService.update_tree(body, 0.2), "native production tree selects encounter")
	_check(job.status == NpcHomeDelivery.Status.AMBUSHED and CombatService.target_for(body) == player, "tree requests combat without receiving box")
	_check(InteractionControlFocus.current(player) < InteractionControlFocus.Priority.MODAL and NpcDialogueService.participant(body) == null, "conversation and input released")
	_check(NpcHomeDeliveryService.meeting_for(body) == null and not body.has_component(C_CustomerAgent), "home and service reservations released")
	_check(not NpcDeliveryScenarioService.start_ambush(body), "ambush cannot repeat")
	_check(CustomerFlowService.parcel_for(job.package_id) != null and WalletService.current().operations.is_empty(), "real box and money remain unchanged")
	panel.close_dialogue()
	DialogueResourceLifecycle.release_runtime_references(resource)

func _prompt(resource: DialogueResource, context: NpcDialogueContext, cue: String) -> DialogueLine:
	var line: DialogueLine = await resource.get_next_dialogue_line(cue, [{"ctx": context}])
	for step: int in range(5):
		if line == null or not line.responses.is_empty():
			return line
		line = await resource.get_next_dialogue_line(line.next_id, [{"ctx": context}])
	return line
#endregion

#region Вспомогательные проверки
func _personal_job(district: C_District) -> NpcHomeDelivery:
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.source == NpcHomeDelivery.Source.PERSONAL:
			return job
	return null

func _door(address_id: StringName) -> Entity:
	for door: Entity in ECS.world.query.with_all([C_NpcAddress]).execute():
		if (door.get_component(C_NpcAddress) as C_NpcAddress).address_id == address_id:
			return door
	return null

func _cleanup_slot() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Personal delivery dialogue smoke: " + message)
#endregion
