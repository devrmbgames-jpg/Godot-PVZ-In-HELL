extends GutTest


func _definition(policy: DEF_ProlongedInteraction.ResetPolicy) -> DEF_ProlongedInteraction:
	var definition: DEF_ProlongedInteraction = DEF_ProlongedInteraction.new()
	definition.duration_seconds = 1.5
	definition.reset_policy = policy
	return definition


func test_default_duration_and_one_success_per_hold() -> void:
	var definition: DEF_ProlongedInteraction = DEF_ProlongedInteraction.new()
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	assert_eq(definition.duration_seconds, 6.0)
	assert_false(ProlongedProgressService.advance(progress, definition, 3.0, true))
	assert_almost_eq(progress.fraction, 0.5, 0.0001)
	assert_false(ProlongedProgressService.commit_success(progress, definition))
	assert_true(ProlongedProgressService.advance(progress, definition, 3.0, true))
	assert_true(ProlongedProgressService.commit_success(progress, definition))
	assert_false(ProlongedProgressService.commit_success(progress, definition))
	assert_false(ProlongedProgressService.advance(progress, definition, 10.0, true))


func test_instant_reset_does_not_complete_interrupted_action() -> void:
	var definition: DEF_ProlongedInteraction = _definition(DEF_ProlongedInteraction.ResetPolicy.INSTANT)
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	ProlongedProgressService.advance(progress, definition, 1.0, true)
	ProlongedProgressService.interrupt(progress, definition)
	assert_eq(progress.fraction, 0.0)
	assert_eq(progress.phase, ProlongedInteractionProgress.Phase.IDLE)
	assert_false(ProlongedProgressService.commit_success(progress, definition))


func test_decay_rate_is_independent_of_action_duration() -> void:
	var definition: DEF_ProlongedInteraction = _definition(DEF_ProlongedInteraction.ResetPolicy.DECAY)
	definition.duration_seconds = 4.0
	definition.decay_per_second = 0.25
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	ProlongedProgressService.advance(progress, definition, 2.0, true)
	ProlongedProgressService.advance(progress, definition, 1.0, false)
	assert_almost_eq(progress.fraction, 0.25, 0.0001)
	ProlongedProgressService.advance(progress, definition, 20.0, false)
	assert_eq(progress.fraction, 0.0)


func test_on_complete_retains_partial_progress_and_resets_only_after_success() -> void:
	var definition: DEF_ProlongedInteraction = _definition(DEF_ProlongedInteraction.ResetPolicy.ON_COMPLETE)
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	ProlongedProgressService.advance(progress, definition, 0.75, true)
	ProlongedProgressService.advance(progress, definition, 10.0, false)
	assert_eq(progress.fraction, 0.5)
	assert_true(ProlongedProgressService.advance(progress, definition, 0.75, true))
	assert_eq(progress.fraction, 1.0)
	assert_true(ProlongedProgressService.commit_success(progress, definition))
	assert_eq(progress.fraction, 0.0)
	assert_false(ProlongedProgressService.advance(progress, definition, 1.5, true))
	ProlongedProgressService.interrupt(progress, definition)
	assert_true(ProlongedProgressService.advance(progress, definition, 1.5, true))


func test_never_is_persistent_one_shot_even_after_release_and_copy() -> void:
	var definition: DEF_ProlongedInteraction = _definition(DEF_ProlongedInteraction.ResetPolicy.NEVER)
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	ProlongedProgressService.advance(progress, definition, 0.75, true)
	ProlongedProgressService.interrupt(progress, definition)
	assert_eq(progress.fraction, 0.5)
	ProlongedProgressService.advance(progress, definition, 0.75, true)
	ProlongedProgressService.commit_success(progress, definition)

	var restored: ProlongedInteractionProgress = progress.duplicate(true) as ProlongedInteractionProgress
	ProlongedProgressService.advance(restored, definition, 100.0, false)
	assert_false(ProlongedProgressService.advance(restored, definition, 100.0, true))
	assert_false(ProlongedProgressService.commit_success(restored, definition))
	assert_eq(restored.fraction, 1.0)


func test_interruption_at_ready_never_commits_effect() -> void:
	var definition: DEF_ProlongedInteraction = _definition(DEF_ProlongedInteraction.ResetPolicy.ON_COMPLETE)
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	ProlongedProgressService.advance(progress, definition, 1.5, true)
	ProlongedProgressService.interrupt(progress, definition)
	assert_false(ProlongedProgressService.commit_success(progress, definition))
	assert_eq(progress.fraction, 1.0)
	assert_true(ProlongedProgressService.advance(progress, definition, 0.0, true))


func test_invalid_timing_cannot_complete_or_mutate_progress() -> void:
	var definition: DEF_ProlongedInteraction = DEF_ProlongedInteraction.new()
	var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
	assert_false(ProlongedProgressService.advance(progress, definition, -1.0, true))
	assert_false(ProlongedProgressService.advance(progress, definition, NAN, true))
	assert_false(ProlongedProgressService.advance(progress, definition, INF, true))
	definition.duration_seconds = 0.0
	assert_false(ProlongedProgressService.advance(progress, definition, 1.0, true))
	assert_eq(progress.fraction, 0.0)
	assert_eq(progress.phase, ProlongedInteractionProgress.Phase.IDLE)
