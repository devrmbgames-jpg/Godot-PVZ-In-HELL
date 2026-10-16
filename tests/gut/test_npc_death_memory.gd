extends "res://tests/gut/test_npc_life_cycle.gd"
## Terminal LOS, personal belief, finite return reactions and real Dialogue Manager presentation.

var _return_resource: DialogueResource = null


#region Physical attackers and actual terminal damage
func after_each() -> void:
	if _return_resource != null:
		DialogueResourceLifecycle.release_runtime_references(_return_resource)
		_return_resource = null
	for node: Node in get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP):
		var panel: CustomerDialoguePanel = node as CustomerDialoguePanel
		if panel != null:
			panel.close_dialogue()
			panel.free()
	super.after_each()


func _player_actor() -> Entity:
	var physical: RigidBody3D = RigidBody3D.new()
	physical.set_script(E_RigidBodyCharacter)
	var player: Entity = physical as Node as Entity
	var anchor: Marker3D = Marker3D.new()
	physical.add_child(anchor)
	(player as E_RigidBodyCharacter).head_axis_x = anchor
	(player as E_RigidBodyCharacter).hold_anchor = anchor
	player.component_resources = [
		C_PlayerInputController.new(),
		C_GrabControl.new(),
		C_Health.new(),
		C_Controller.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
		C_Motion.new(),
	]
	_world.add_entity(player)
	physical.freeze = true
	physical.set_physics_process(false)
	return player


func _street(person: NpcRecord, offset: float = 15.0) -> E_DistrictNpc:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var position: Vector3 = NpcPopulationQueries.position_for(person.home_id, true)
	position.z += offset
	assert_true(
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"memory_test",
			false,
			position,
		)
	)
	body.rotation = Vector3.ZERO
	var head: Node3D = body.get_node_or_null("HeadY") as Node3D
	if head != null:
		head.rotation = Vector3.ZERO
	return body


func _damage(body: E_DistrictNpc, actor: Entity, combat: bool = true) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.target = body
	request.instigator = actor
	request.source = actor
	request.amount = (body.get_component(C_Health) as C_Health).value * 2.0
	request.damage_type = DamageRequest.Type.GENERIC
	if combat:
		request.combat_context = CombatContext.new()
		request.combat_context.actor_is_player = NpcSocialService.identity_for(actor) == &"player"
	DamageRequestService.submit(request)
	assert_true(body.has_component(C_Death))


func _synchronize_geometry() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _wall_between(body: E_DistrictNpc) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(5.0, 4.0, 0.3)
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.global_position = body.global_position + Vector3(0.0, 1.5, -0.75)
	return wall
#endregion


#region Knowledge without omniscient blame
func test_recognized_player_is_remembered_without_a_grudge_trait_and_roundtrips() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _street(person)
	var player: Entity = _player_actor()
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD * 1.5
	await _synchronize_geometry()
	assert_true(NpcPerceptionService.can_see(body, player, person))
	assert_null(NpcGrudgeRules.capability(person))
	var position: Vector3 = body.global_position
	_damage(body, player)
	var episode: NpcDeathRecord = person.deaths[0]
	assert_eq(episode.actual_actor_id, &"player")
	assert_eq(episode.known_actor_id, &"player")
	assert_eq(episode.suspected_actor_id, &"")
	assert_eq(episode.position, position)
	assert_eq(episode.damage_type, DamageRequest.Type.GENERIC)
	assert_false(NpcPerceptionService.can_see(body, player, person))
	assert_false(
		NpcPerceptionService.can_see_at_death(
			body,
			player,
			person,
			body.get_component(C_Death) as C_Death,
		),
		"Dormant old corpses cannot acquire new knowledge",
	)
	_world.remove_entity(player)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	person = NpcPopulationQueries.person_for(person.npc_id)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
	assert_eq(person.deaths[0].known_actor_id, &"player")
	var encoded: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = SaveDataCodec.decode(encoded) as NpcRecord
	assert_not_null(restored)
	assert_eq(restored.deaths[0].known_actor_id, &"player")
	assert_eq(restored.deaths[0].position, position)
	assert_true(NpcLifeRules.valid_history(restored, 1))
	for other: NpcRecord in _district.people:
		if other != person:
			assert_true(other.deaths.is_empty())
			assert_true(other.memories.is_empty())


func test_wall_hides_actual_player_and_never_grants_blame() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _street(person)
	var player: Entity = _player_actor()
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD * 1.5
	_wall_between(body)
	await _synchronize_geometry()
	assert_false(NpcPerceptionService.can_see(body, player, person))
	_damage(body, player)
	var episode: NpcDeathRecord = person.deaths[0]
	assert_eq(episode.actual_actor_id, &"player")
	assert_eq(episode.known_actor_id, &"")
	assert_eq(episode.suspected_actor_id, &"")
	assert_eq(episode.reaction, NpcMemory.Reaction.TALK)


func test_previous_seen_opponent_remains_only_a_suspicion_after_hidden_terminal_damage() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _street(person)
	var player: Entity = _player_actor()
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD * 1.5
	await _synchronize_geometry()
	assert_true(NpcPerceptionService.can_see(body, player, person))
	assert_true(CombatService.bind_target(body, player))
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.has_last_seen = true
	awareness.last_seen_position = (player as Node as Node3D).global_position
	_wall_between(body)
	await _synchronize_geometry()
	_damage(body, player)
	var episode: NpcDeathRecord = person.deaths[0]
	assert_eq(episode.known_actor_id, &"")
	assert_eq(episode.suspected_actor_id, &"player")
	assert_eq(episode.reaction, NpcMemory.Reaction.TALK)
	assert_true(NpcLifeRules.valid_history(person, 1))


func test_environment_does_not_blame_a_visible_source_owner() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _street(person)
	var player: Entity = _player_actor()
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD * 1.5
	await _synchronize_geometry()
	_damage(body, player, false)
	assert_eq(person.deaths[0].actual_actor_id, &"player")
	assert_eq(person.deaths[0].known_actor_id, &"")
	assert_eq(person.deaths[0].suspected_actor_id, &"")
	_morning(3)
	_street(person, 25.0)
	assert_false(NpcCommunityService.react_to_return(body, person))
	assert_null(CombatQueries.target_for(body))


func test_recognized_npc_response_spends_one_ambient_conflict_and_does_not_restart() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/9")
	var body: E_DistrictNpc = _street(person)
	var killer: NpcRecord = NpcPopulationQueries.person_for(&"npc/6")
	var target: E_DistrictNpc = _street(killer)
	target.place_at(body.global_position + Vector3.FORWARD * 1.5)
	await _synchronize_geometry()
	_damage(body, target)
	var episode: NpcDeathRecord = person.deaths[0]
	assert_eq(episode.known_actor_id, killer.npc_id)
	assert_eq(episode.actual_actor_id, killer.npc_id)
	assert_false(episode.response_given)
	_morning(3)
	_street(person, 25.0)
	_street(killer, 25.0)
	target.place_at(body.global_position + Vector3.FORWARD * 1.5)
	# Fixed reaction isolates the existing conflict budget from authored probability.
	episode.reaction = NpcMemory.Reaction.ATTACK
	person.profile = person.profile.duplicate() as DEF_NpcArchetype
	person.profile.initiates_conflicts = true
	await _synchronize_geometry()
	_district.ambient_conflicts = _district.definition.ambient_conflicts_per_phase
	assert_false(NpcCommunityService.react_to_return(body, person))
	assert_false(episode.reaction_applied)
	_district.ambient_conflicts = 0
	var idle: BehaviorTree = load("res://content/domains/npc/ai/trees/bt_npc_idle.tres")
	var branch: BTSubtree = idle.get_root_task().get_child(0) as BTSubtree
	assert_eq(
		branch.subtree.resource_path,
		"res://content/domains/npc/ai/trees/bt_npc_return_reaction.tres",
	)
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	runner.behavior_tree = branch.subtree
	(body.get_component(C_NpcDecision) as C_NpcDecision).intent_owner = C_NpcDecision.Owner.NONE
	assert_true(NpcBrainService.update_tree(body, 0.2))
	assert_true(episode.reaction_applied)
	assert_eq(_district.ambient_conflicts, 1)
	assert_same(CombatQueries.target_for(body), target)
	assert_string_contains((body.get_node("Message") as Label3D).text, "Ты меня убил")
	CombatService.end_combat(body)
	assert_false(NpcCommunityService.react_to_return(body, person))
	assert_eq(_district.ambient_conflicts, 1)
	assert_null(CombatQueries.target_for(body))
	assert_false(
		episode.response_given,
		"NPC encounter does not consume the later personal dialogue",
	)
#endregion


#region Dialogue compilation and first presented response
func test_return_dialogue_is_prioritized_and_only_a_presented_line_consumes_it() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _street(person)
	var player: Entity = _player_actor()
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD * 1.5
	await _synchronize_geometry()
	_damage(body, player)
	_morning(3)
	_street(person, 25.0)
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	await _synchronize_geometry()
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(player, body)
	assert_true(context.begin())
	assert_eq(context.dialogue_cue(), "return_memory")
	var compiled: DMCompilerResult = DMCompiler.compile_string(
		FileAccess.get_file_as_string(NpcDialogueService.RETURN_DIALOGUE_PATH),
		NpcDialogueService.RETURN_DIALOGUE_PATH,
	)
	assert_eq(compiled.errors.size(), 0)
	_return_resource = load(NpcDialogueService.RETURN_DIALOGUE_PATH) as DialogueResource
	var line: DialogueLine = await _return_resource.get_next_dialogue_line(
		"return_memory",
		[{ "ctx": context }],
	)
	assert_not_null(line)
	assert_eq(line.character, person.display_name)
	assert_string_contains(line.text, "ты меня убил")
	assert_true(line.tags.has("return_memory"))
	assert_false(
		person.deaths[0].response_given,
		"Reading a cancelled async line is not presentation",
	)
	context.note_line_presented(line.tags)
	assert_true(person.deaths[0].response_given)
	context.note_line_presented(line.tags)
	assert_eq(person.deaths.size(), 1)
	assert_ne(context.dialogue_cue(), "return_memory")
	context.end()
	assert_false(NpcSocialService.note_return_response(body, 1))
	assert_true(NpcCommunityService.react_to_return(body, person))
	assert_true(person.deaths[0].reaction_applied)
	assert_false(NpcCommunityService.react_to_return(body, person))
	assert_true(NpcLifeRules.valid_history(person, 3))


func test_death_knowledge_rejects_false_certainty_and_premature_acknowledgement() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	_kill(person)
	var episode: NpcDeathRecord = person.deaths[0]
	assert_true(NpcLifeRules.valid_history(person, 1))
	episode.known_actor_id = &"player"
	assert_false(NpcLifeRules.valid_history(person, 1))
	episode.actual_actor_id = &"player"
	assert_true(NpcLifeRules.valid_history(person, 1))
	episode.suspected_actor_id = &"npc/6"
	assert_false(NpcLifeRules.valid_history(person, 1))
	episode.suspected_actor_id = &""
	episode.response_given = true
	assert_false(NpcLifeRules.valid_history(person, 1))
	episode.response_given = false
	episode.position.x = NAN
	assert_false(NpcLifeRules.valid_history(person, 1))


func test_native_panel_routes_the_first_return_line_and_does_not_repeat_on_reopen() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	_kill(person)
	_morning(3)
	var body: E_DistrictNpc = _street(person, 25.0)
	var player: Entity = _player_actor()
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	_return_resource = load(NpcDialogueService.RETURN_DIALOGUE_PATH) as DialogueResource
	assert_true(DialoguePanelRouter.open_street(player, body))
	for frame: int in 16:
		if person.deaths[0].response_given:
			break
		await get_tree().process_frame
	assert_true(person.deaths[0].response_given)
	assert_true(
		person.deaths[0].reaction_applied,
		"Unknown death cannot initiate a personal attack",
	)
	var panels: Array[Node] = get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP)
	assert_eq(panels.size(), 1)
	var panel: CustomerDialoguePanel = panels[0] as CustomerDialoguePanel
	panel.close_dialogue()
	panel.free()
	assert_true(DialoguePanelRouter.open_street(player, body))
	await get_tree().process_frame
	assert_true(person.deaths[0].response_given)
	assert_eq(person.deaths.size(), 1)


func test_closed_episode_fields_and_unknown_authored_actor_reject_before_live_mutation() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _kill(person)
	var encoded: Dictionary = SaveDataCodec.encode(person.deaths[0]) as Dictionary
	for field: String in NpcDeathRecord.SAVE_FIELDS:
		var malformed: Dictionary = encoded.duplicate(true)
		(malformed.fields as Dictionary).erase(field)
		assert_null(SaveDataCodec.decode(malformed), field)
	var episode: NpcDeathRecord = person.deaths[0]
	episode.actual_actor_id = &"npc/999"
	episode.known_actor_id = &"npc/999"
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)

#endregion
