extends "res://tests/gut/test_npc_dark_predator.gd"
## Native audio/shadow projection follows committed facts and releases all presentation work.

var _presentation_owner: S_NpcNightPresentation


#region Actual System and native transitions
func before_each() -> void:
	_presentation_owner = null
	await super.before_each()


func _tick_view() -> void:
	if _presentation_owner == null:
		_presentation_owner = S_NpcNightPresentation.new()
		_presentation_owner.group = "NightPresentationFixture"
		_world.add_system(_presentation_owner)
	_world.process(0.0, "NightPresentationFixture")


func _music() -> AudioStreamPlayer3D:
	return _actor.get_node("NightPresence/Music") as AudioStreamPlayer3D


func _shadow() -> Decal:
	return _actor.get_node("NightPresence/Shadow") as Decal


func _view() -> NpcNightPresentation:
	return _actor.get_node("NightPresence") as NpcNightPresentation


func _wait_volume(expected: float) -> void:
	var deadline: int = Time.get_ticks_msec() + 2000
	while not is_equal_approx(_music().volume_db, expected) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_almost_eq(_music().volume_db, expected, 0.001)
#endregion


#region Authored presence and fact projection
func test_authored_presence_has_native_spatial_audio_shadow_and_external_tuning() -> void:
	assert_eq(
		_view().definition.resource_path,
		"res://content/domains/npc/definitions/def_npc_night_presentation.tres",
	)
	assert_is(_music().stream, AudioStreamWAV)
	assert_almost_eq(_music().stream.get_length(), 12.0, 0.001)
	assert_not_null(_shadow().texture_albedo)
	assert_eq(_shadow().texture_albedo.get_width(), 128)
	assert_false(_music().autoplay)
	assert_false(_music().playing)
	assert_false(_shadow().visible)
	assert_almost_eq(_music().max_distance, _view().definition.music_distance, 0.001)


func test_presence_transition_is_idempotent_and_preserves_gameplay_authority() -> void:
	var person_snapshot: Dictionary = SaveDataCodec.encode(_person) as Dictionary
	var generation: int = _decision.lifecycle_generation
	var world_pose: Transform3D = _actor.global_transform
	_tick_view()
	assert_true(_music().playing)
	assert_true(_shadow().visible)
	var transitions: int = get_tree().get_processed_tweens().size()
	assert_gt(transitions, 0)
	_tick_view()
	assert_eq(get_tree().get_processed_tweens().size(), transitions)
	await _wait_volume(_view().definition.presence_volume_db)
	assert_almost_eq(_shadow().modulate.a, _view().definition.presence_shadow_opacity, 0.001)
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_decision.lifecycle_generation, generation)
	assert_eq(SaveDataCodec.encode(_person), person_snapshot)
	assert_eq(_actor.global_transform, world_pose)


func test_real_hunt_and_light_calm_change_only_native_warning_intensity() -> void:
	_tick_view()
	await _wait_volume(_view().definition.presence_volume_db)
	_step()
	assert_same(CombatQueries.target_for(_actor), _player)
	var person_snapshot: Dictionary = SaveDataCodec.encode(_person) as Dictionary
	_tick_view()
	await _wait_volume(_view().definition.hunting_volume_db)
	assert_almost_eq(_shadow().modulate.a, _view().definition.hunting_shadow_opacity, 0.001)
	assert_same(CombatQueries.target_for(_actor), _player)
	_zone(Vector3.UP)
	_step()
	assert_null(CombatQueries.target_for(_actor))
	_tick_view()
	await _wait_volume(_view().definition.presence_volume_db)
	assert_almost_eq(_shadow().modulate.a, _view().definition.presence_shadow_opacity, 0.001)
	assert_eq(SaveDataCodec.encode(_person), person_snapshot)
	assert_true(_music().playing)


func test_dormancy_and_death_stop_native_work_at_the_cleanup_boundary() -> void:
	_tick_view()
	assert_true(_music().playing)
	assert_true(
		DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.OUTSIDE)
	)
	assert_false(_music().playing, "Cleanup does not wait for another scheduled projection")
	assert_false(_shadow().visible)
	assert_eq(_shadow().modulate.a, 0.0)
	_tick_view()
	assert_false(_music().playing)
	# Reactivate through the same retained-body owner, then confirm terminal cleanup.
	assert_true(
		DistrictPopulationService.set_placement(_person, _actor, NpcRecord.Placement.STREET)
	)
	_tick_view()
	assert_true(_music().playing)
	_actor.add_component(C_Death.new())
	_actor.request_role_cleanup(NpcRoleCleanupRequest.Kind.DEATH, 1)
	assert_false(_music().playing)
	assert_false(_shadow().visible)
	_tick_view()
	assert_false(_music().playing)


func test_reset_and_profile_replacement_cannot_keep_previous_presence_work() -> void:
	_step()
	_tick_view()
	assert_true(_music().playing)
	DistrictPopulationService.reset_brain(_actor)
	assert_false(_music().playing)
	assert_false(_shadow().visible)
	_tick_view()
	await _wait_volume(_view().definition.presence_volume_db)
	var replacement: DEF_NpcArchetype = load(
		"res://content/domains/npc/definitions/def_npc_archetype_lost.tres"
	) as DEF_NpcArchetype
	_person.profile = replacement
	_person.variation = NpcVariationRules.create(replacement, 1234, _person.npc_id, 1)
	_actor.present_profile(replacement)
	assert_false(_music().playing)
	assert_false(_shadow().visible)
	_tick_view()
	assert_false(_music().playing)


func test_authored_music_and_shadow_cues_remain_independent_and_free_with_the_actor() -> void:
	var profile: DEF_NpcArchetype = PROFILE.duplicate(true) as DEF_NpcArchetype
	_person.profile = profile
	profile.presentation_cues = PackedStringArray([S_NpcNightPresentation.MUSIC_CUE])
	_tick_view()
	assert_true(_music().playing)
	assert_false(_shadow().visible)
	profile.presentation_cues = PackedStringArray([S_NpcNightPresentation.SHADOW_CUE])
	_tick_view()
	assert_false(_music().playing)
	assert_true(_shadow().visible)
	var transitions: Array[Tween] = get_tree().get_processed_tweens()
	var reference: WeakRef = weakref(_view())
	_world.remove_entity(_actor)
	_actor.free()
	assert_null(reference.get_ref())
	for transition: Tween in transitions:
		assert_false(transition.is_valid())
	# SceneTree removes killed native Tweens during its next frame progression.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(get_tree().get_processed_tweens().size(), 0)
#endregion
