extends "res://tests/gut/test_npc_ranged_combat.gd"
## Actual lasting personal incidents, actor-specific reaction changes and stable save/body identity.

const LEGACY_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_lost.tres"
)


#region Personal memory fixtures
func _incident_in_band(kind: NpcMemory.Kind, low: float, high: float, label: String) -> StringName:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	for index: int in 512:
		var incident: StringName = StringName("grudge/%s/%d" % [label, index])
		var random: RandomNumberGenerator = GameTimeQueries.decision(
			String(_person.npc_id),
			cycle.day_index,
			"npc/social/%d/%s" % [kind, incident],
		)
		var roll: float = random.randf()
		if roll > low and roll < high:
			return incident
	fail_test("No deterministic incident in the requested comparison band")
	return &""


func _stranger() -> Entity:
	var body: CharacterBody3D = CharacterBody3D.new()
	body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var actor: Entity = body as Node as Entity
	var identity: C_NpcIdentity = C_NpcIdentity.new()
	identity.npc_id = &"grudge/stranger"
	actor.component_resources = [identity, C_Health.new()]
	_world.add_entity(actor)
	return actor
#endregion


#region Actual durable resentment
func test_due_trait_sampling_creates_no_grudge_clock_or_social_incident() -> void:
	var snapshot: Dictionary = SaveDataCodec.encode(_person) as Dictionary
	NpcAiFixture.traits(_actor, _person, _player, 0.1)
	assert_false(_awareness.rule_exposure.has(DEF_NpcTrait.Kind.CAPABILITY))
	assert_false(_awareness.warned_rules.has(DEF_NpcTrait.Kind.CAPABILITY))
	assert_eq(SaveDataCodec.encode(_person), snapshot)
	assert_null(CombatQueries.target_for(_actor))


func test_native_hag_has_valid_bounded_capability_and_legacy_actor_has_none() -> void:
	var rule: DEF_NpcGrudge = NpcGrudgeRules.capability(_person)
	assert_not_null(rule)
	assert_true(rule.valid_configuration())
	assert_true(HAG.valid_rules())
	assert_almost_eq(rule.attack_probability_bonus, 0.2, 0.001)
	var legacy: NpcRecord = NpcRecord.new()
	legacy.npc_id = &"grudge/legacy"
	legacy.profile = LEGACY_PROFILE
	legacy.variation = NpcVariationRules.create(legacy.profile, 1234, legacy.npc_id, 1)
	assert_null(NpcGrudgeRules.capability(legacy))
	for invalid: float in [-0.1, 1.1, NAN, INF]:
		var tuning: DEF_NpcGrudge = rule.duplicate(true) as DEF_NpcGrudge
		tuning.attack_probability_bonus = invalid
		assert_false(tuning.valid_configuration())


func test_only_personal_recognized_offender_counts_and_query_changes_no_state() -> void:
	var stranger: Entity = _stranger()
	NpcSocialService.remember(_person, _player, stranger, NpcMemory.Kind.ATTACK, &"grudge/witness")
	NpcSocialService.remember(_person, _player, _actor, NpcMemory.Kind.HELP, &"grudge/help")
	assert_false(NpcGrudgeRules.remembers_offender(_person, &"player"))
	NpcSocialService.remember(_person, _player, _actor, NpcMemory.Kind.LIE, &"grudge/personal")
	var snapshot: Dictionary = SaveDataCodec.encode(_person) as Dictionary
	for repeat: int in 3:
		assert_true(NpcGrudgeRules.remembers_offender(_person, &"player"))
		assert_false(NpcGrudgeRules.remembers_offender(_person, &"grudge/stranger"))
		assert_false(NpcGrudgeRules.remembers_offender(_person, &""))
		assert_true(NpcDialogueService.has_grudge_against(_actor, _player))
		assert_false(NpcDialogueService.has_grudge_against(_actor, stranger))
	assert_eq(SaveDataCodec.encode(_person), snapshot)
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(_person.activity_sequence, 0)


func test_new_lie_uses_prior_grudge_but_replayed_incident_cannot_reroll() -> void:
	var base: float = HAG.high_attack_probability * _person.variation.aggression_multiplier
	var bonus: float = NpcGrudgeRules.capability(_person).attack_probability_bonus
	var low: float = base + HAG.low_flee_probability
	var high: float = minf(1.0, base + bonus)
	assert_lt(low, high)
	var first: StringName = _incident_in_band(NpcMemory.Kind.LIE, low, high, "first")
	assert_eq(
		NpcSocialService.react(_actor, _player, NpcMemory.Kind.LIE, first),
		NpcMemory.Reaction.TALK,
	)
	assert_true(NpcGrudgeRules.remembers_offender(_person, &"player"))
	assert_null(CombatQueries.target_for(_actor))
	assert_eq(
		NpcSocialService.react(_actor, _player, NpcMemory.Kind.LIE, first),
		NpcMemory.Reaction.TALK,
	)
	assert_eq(_person.memories.size(), 1)
	var second: StringName = _incident_in_band(NpcMemory.Kind.LIE, low, high, "second")
	assert_eq(
		NpcSocialService.react(_actor, _player, NpcMemory.Kind.LIE, second),
		NpcMemory.Reaction.ATTACK,
	)
	assert_same(CombatQueries.target_for(_actor), _player)
	assert_eq(_person.memories.size(), 2)
	CombatService.end_combat(_actor)
	assert_eq(
		NpcSocialService.react(_actor, _player, NpcMemory.Kind.LIE, second),
		NpcMemory.Reaction.ATTACK,
	)
	assert_null(
		CombatQueries.target_for(_actor),
		"Replay reads the committed result without reapplying combat",
	)


func test_grudge_lowers_brazen_respect_threshold_only_for_its_offender() -> void:
	var threshold: float = HAG.high_attack_probability
	var bonus: float = NpcGrudgeRules.capability(_person).attack_probability_bonus
	var first: StringName = _incident_in_band(
		NpcMemory.Kind.THREAT,
		threshold - bonus,
		threshold,
		"threat",
	)
	assert_eq(
		NpcSocialService.react(_actor, _player, NpcMemory.Kind.THREAT, first),
		NpcMemory.Reaction.RESPECT,
	)
	var stranger: Entity = _stranger()
	var second: StringName = _incident_in_band(
		NpcMemory.Kind.THREAT,
		threshold - bonus,
		threshold,
		"stranger",
	)
	assert_eq(
		NpcSocialService.react(_actor, stranger, NpcMemory.Kind.THREAT, second),
		NpcMemory.Reaction.RESPECT,
	)
	var third: StringName = _incident_in_band(
		NpcMemory.Kind.THREAT,
		threshold - bonus,
		threshold,
		"repeat",
	)
	assert_eq(
		NpcSocialService.react(_actor, _player, NpcMemory.Kind.THREAT, third),
		NpcMemory.Reaction.ATTACK,
	)
	assert_same(CombatQueries.target_for(_actor), _player)


func test_personal_grudge_survives_day_body_reset_and_save_without_stacking() -> void:
	NpcSocialService.remember(_person, _player, _actor, NpcMemory.Kind.OFFENSE, &"grudge/old")
	NpcSocialService.remember(_person, _player, _actor, NpcMemory.Kind.LIE, &"grudge/second")
	var bonus: float = NpcGrudgeRules.attack_bonus(_person, &"player")
	DayPhaseQueries.current().day_index += 20
	DistrictPopulationService.reset_brain(_actor)
	NpcBrainService.bind_engine(_actor)
	var restored: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_eq(restored.npc_id, _person.npc_id)
	assert_eq(restored.memories.size(), 2)
	assert_true(NpcGrudgeRules.remembers_offender(restored, &"player"))
	assert_eq(NpcGrudgeRules.attack_bonus(restored, &"player"), bonus)
	assert_true(NpcDialogueService.has_grudge_against(_actor, _player))
	assert_null(CombatQueries.target_for(_actor))
	assert_false(_intent().movement_active)


func test_bodyless_promise_preserves_personal_identity_and_legacy_memory() -> void:
	NpcSocialService.remember_promise(_person, null, null, &"grudge/promise")
	assert_eq(_person.memories.size(), 1)
	assert_eq(_person.memories[0].actor_id, &"player")
	assert_eq(_person.memories[0].victim_id, _person.npc_id)
	assert_true(NpcGrudgeRules.remembers_offender(_person, &"player"))
	var snapshot: Dictionary = SaveDataCodec.encode(_person) as Dictionary
	NpcSocialService.remember_promise(_person, null, null, &"grudge/promise")
	assert_eq(SaveDataCodec.encode(_person), snapshot)
	_person.memories[0].victim_id = &""
	assert_true(NpcGrudgeRules.remembers_offender(_person, &"player"))
	var restored: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_true(NpcGrudgeRules.remembers_offender(restored, &"player"))
#endregion
