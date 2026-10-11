extends GutTest
## Alignment bounds, threshold edges, invalid tuning and native player trait composition.


#region Pure alignment policy and synchronous mutation
func test_strict_thresholds_leave_both_boundary_values_neutral() -> void:
	var karma: C_Karma = C_Karma.new()
	for value: float in [-25.0, 0.0, 25.0]:
		karma.value = value
		assert_false(KarmaRules.is_low(karma))
		assert_false(KarmaRules.is_high(karma))
	karma.value = -25.01
	assert_true(KarmaRules.is_low(karma))
	assert_false(KarmaRules.is_high(karma))
	karma.value = 25.01
	assert_true(KarmaRules.is_high(karma))
	assert_false(KarmaRules.is_low(karma))


func test_explicit_mutations_clamp_bounds_and_reject_non_finite_input() -> void:
	var actor: Entity = Entity.new()
	var karma: C_Karma = C_Karma.new()
	actor.add_component(karma)
	assert_true(KarmaService.set_value(actor, -200.0))
	assert_eq(karma.value, -100.0)
	assert_true(KarmaService.adjust(actor, 300.0))
	assert_eq(karma.value, 100.0)
	for invalid: float in [NAN, INF, -INF]:
		assert_false(KarmaService.set_value(actor, invalid))
		assert_false(KarmaService.adjust(actor, invalid))
		assert_eq(karma.value, 100.0)
	actor.free()


func test_invalid_policy_and_saved_values_cannot_classify_as_eligible() -> void:
	var karma: C_Karma = C_Karma.new()
	karma.policy = karma.policy.duplicate() as DEF_KarmaPolicy
	karma.policy.low_threshold = karma.policy.high_threshold
	assert_false(KarmaRules.valid(karma))
	assert_false(KarmaRules.is_low(karma))
	assert_false(KarmaRules.is_high(karma))
	karma.policy.low_threshold = -25.0
	karma.value = NAN
	assert_false(KarmaRules.valid(karma))
	karma.value = 101.0
	assert_false(KarmaRules.valid(karma))
	karma.value = 0.0
	karma.policy.maximum_value = INF
	assert_false(KarmaRules.valid(karma))
	karma.policy = null
	assert_false(KarmaRules.valid(karma))


## Native player and its placed main-level override both receive exactly one fresh karma recipe.
func test_native_player_trait_survives_placed_component_overrides() -> void:
	var packed: PackedScene = load(
		"res://content/domains/motion/entities/character_body_player.tscn"
	) as PackedScene
	var standalone: Entity = packed.instantiate() as Entity
	var level: Node = (load(GameSessionService.MAIN_LEVEL) as PackedScene).instantiate()
	var placed: Entity = level.get_node("Entityes/Player") as Entity
	var recipes: Array[C_Karma] = []
	for actor: Entity in [standalone, placed]:
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			null,
			"karma_preview",
		)
		var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
		assert_true(plan.valid())
		var count: int = 0
		for component: Component in plan.component_recipes:
			if component is C_Karma:
				count += 1
				recipes.append(component as C_Karma)
		assert_eq(count, 1)
		assert_not_null(actor.get_node_or_null("BeltSlotLeft"))
		assert_not_null(actor.get_node_or_null("BeltSlotRight"))
	if recipes.size() == 2:
		assert_ne(recipes[0], recipes[1])
		recipes[0].value = -40.0
		assert_eq(recipes[1].value, 0.0)
	standalone.free()
	level.free()

#endregion
