extends "res://tests/gut/test_district_population.gd"
## Real player/dealer, common Health callbacks and closed personal blood confirmation regressions.

const PLAYER: PackedScene = preload(
	"res://content/domains/motion/entities/character_body_player.tscn"
)
const VAMPIRE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_vampire.tres"
)

var _original_profile: DEF_NpcArchetype
var _original_variation: NpcVariation
var _person: NpcRecord
var _player: Entity
var _dealer: E_DistrictNpc
var _health: C_Health
var _probe: HealthResultProbe


## Captures the actual common result and can retire either participant during publication.
class HealthResultProbe extends Observer:
	var results: Array[DamageResult] = []
	var retire: Entity = null


	#region Native Health result boundary
	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		results.append(payload as DamageResult)
		if retire != null:
			cmd.add_custom(_retire)


	func _retire() -> void:
		var actor: Entity = retire
		retire = null
		_world.remove_entity(actor)
		actor.free()
	#endregion


#region Real participants and confirmation fixture
func _prepare() -> void:
	_person = _district.people[0]
	_original_profile = _person.profile
	_original_variation = _person.variation
	_person.profile = VAMPIRE
	_person.variation = NpcVariationRules.create(VAMPIRE, 1234, _person.npc_id, 1)
	_dealer = NpcPopulationQueries.body_for(_person.npc_id)
	DistrictPopulationService.set_placement(_person, _dealer, NpcRecord.Placement.STREET)
	_dealer.place_at(NpcPopulationQueries.position_for(_person.home_id))
	_player = PLAYER.instantiate() as Entity
	_player.id = "blood/player"
	EntityCompositionFixture.register(_world, _player)
	(_player as Node as Node3D).global_position = _dealer.global_position + Vector3.FORWARD
	(_player as Node).set_physics_process(false)
	_health = _player.get_component(C_Health) as C_Health
	_probe = HealthResultProbe.new()
	_world.add_observer(_probe)
	assert_true(NpcDialogueService.begin(_player, _dealer, true))


func _submit(record: BloodConsentRecord, accept: bool) -> BloodConsentResult:
	var request: BloodConsentRequest = BloodConsentRequest.new()
	request.actor = _player
	request.dealer = _dealer
	request.confirmation_key = record.confirmation_key
	request.accept = accept
	return BloodConsentService.submit(request)


func _fixed_terms(percent: int) -> void:
	_person.profile = VAMPIRE.duplicate(true) as DEF_NpcArchetype
	var rule: DEF_NpcBloodConsent = BloodConsentService.rule_for(_dealer)
	rule.minimum_percent = percent
	rule.maximum_percent = percent


func _snapshot() -> Dictionary:
	_person.profile = _original_profile
	_person.variation = _original_variation
	return WorldSnapshotService.capture(_root, 1)


func _encoded_person(snapshot: Dictionary) -> Dictionary:
	for entity: Dictionary in snapshot.entities:
		for component: Dictionary in entity.components:
			if component.type == C_District.resource_path:
				return (component.fields.people as Array)[0].fields as Dictionary
	return { }
#endregion


#region Actual percentage, idempotency and common result
func test_authored_boundaries_use_current_health_without_changing_limits_or_strength() -> void:
	_prepare()
	for percent: int in [4, 41]:
		_fixed_terms(percent)
		assert_false(BloodConsentService.rule_for(_dealer).valid_configuration())
		assert_null(BloodConsentService.offer(_player, _dealer))
		assert_eq(_person.blood_offer_sequence, 1)
	for percent: int in [5, 40]:
		_fixed_terms(percent)
		_health.current = 60.0
		var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
		assert_not_null(record)
		if record == null:
			return
		assert_eq(record.percent, percent)
		_health.current = 40.0
		var result: BloodConsentResult = _submit(record, true)
		assert_eq(result.reason, &"accepted")
		assert_eq(record.previous_health, 40.0)
		assert_almost_eq(record.applied_amount, 40.0 * percent / 100.0, 0.00001)
		assert_almost_eq(_health.current, 40.0 - record.applied_amount, 0.00001)
		assert_eq(_health.base, 100.0)
		assert_eq(_health.value, 100.0)
		assert_eq((_player.get_component(C_Strength) as C_Strength).value, 1.0)
		assert_false(_health.depleted)
		assert_false(_player.has_component(C_Death))
		assert_true(BloodConsentRules.valid(_person))
		GameTimeQueries.current().elapsed_ticks = record.next_offer_tick
	assert_eq(_probe.results.size(), 2)
	assert_eq(_probe.results[0].request.operation, DamageRequest.Operation.SACRIFICE)


func test_accept_is_sealed_before_reentrant_property_and_result_callbacks() -> void:
	_prepare()
	_fixed_terms(40)
	_health.current = 50.0
	var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	var notifications: Array[float] = []
	_health.property_changed.connect(
		func(_component: Resource, property: StringName, _old: Variant, _new: Variant) -> void:
			if property != _health.definition.key_current:
				return
			notifications.append(_health.current)
			assert_true(BloodConsentRules.valid(_person))
			assert_eq(record.outcome, BloodConsentRecord.Outcome.ACCEPTED)
			assert_true(_submit(record, true).replayed)
			assert_true(_submit(record, false).replayed),
	)
	var result: BloodConsentResult = _submit(record, true)
	assert_false(result.replayed)
	assert_eq(result.reason, &"accepted")
	assert_eq(_health.current, 30.0)
	assert_eq(notifications, [30.0])
	assert_eq(_probe.results.size(), 1)
	assert_eq(_probe.results[0].applied_amount, 20.0)
	assert_eq(_probe.results[0].request.correlation_id, record.confirmation_key)
	for repeat: int in range(3):
		assert_true(_submit(record, true).replayed)
		assert_eq(_submit(record, false).reason, &"accepted")
	assert_eq(_health.current, 30.0)
	assert_eq(_probe.results.size(), 1)


func test_decline_and_session_closure_preserve_health_and_never_reroll_pending_terms() -> void:
	_prepare()
	var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	var encoded: Dictionary = SaveDataCodec.encode(record) as Dictionary
	for repeat: int in range(3):
		assert_same(BloodConsentService.offer(_player, _dealer), record)
	assert_eq(_person.blood_offer_sequence, 2)
	NpcDialogueService.end(_dealer)
	assert_null(BloodConsentService.offer(_player, _dealer))
	assert_eq(SaveDataCodec.encode(record), encoded)
	assert_true(NpcDialogueService.begin(_player, _dealer))
	assert_same(BloodConsentService.offer(_player, _dealer), record)
	assert_eq(_submit(record, false).reason, &"declined")
	assert_eq(_submit(record, true).reason, &"declined")
	assert_eq(record.applied_amount, 0.0)
	assert_eq(_health.current, 100.0)
	assert_true(_probe.results.is_empty())
	assert_false(BloodConsentService.available(_player, _dealer))
	GameTimeQueries.current().elapsed_ticks = record.next_offer_tick
	var next: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	assert_not_null(next)
	assert_ne(next.confirmation_key, record.confirmation_key)
	assert_true(BloodConsentRules.valid(_person))


func test_invalid_health_and_participants_leave_offer_pending_without_publication() -> void:
	_prepare()
	var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	for invalid: float in [0.0, -1.0, INF, NAN, 101.0]:
		_health.current = invalid
		var expected: StringName = (
			&"invalid_health" if invalid > 0.0 else &"participants_unavailable"
		)
		assert_eq(_submit(record, true).reason, expected)
		assert_eq(record.outcome, BloodConsentRecord.Outcome.OFFERED)
	_health.current = 50.0
	NpcDialogueService.end(_dealer)
	assert_eq(_submit(record, true).reason, &"participants_unavailable")
	assert_true(NpcDialogueService.begin(_player, _dealer))
	var identity: String = _player.id
	_player.id = "other/player"
	assert_eq(_submit(record, true).reason, &"offer_mismatch")
	_player.id = identity
	(_player as Node as Node3D).global_position += Vector3.ONE * 100.0
	assert_eq(_submit(record, true).reason, &"participants_unavailable")
	assert_eq(_health.current, 50.0)
	assert_true(_probe.results.is_empty())
	assert_true(BloodConsentRules.valid(_person))


func test_health_publication_can_retire_player_without_stale_access() -> void:
	_prepare()
	var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	var expected: float = 100.0 * (1.0 - record.percent / 100.0)
	_probe.retire = _player
	var result: BloodConsentResult = _submit(record, true)
	assert_eq(result.reason, &"accepted")
	assert_eq(record.outcome, BloodConsentRecord.Outcome.ACCEPTED)
	assert_almost_eq(_health.current, expected, 0.00001)
	assert_false(is_instance_valid(_player))
	assert_true(BloodConsentRules.valid(_person))
	_player = null


func test_consent_ignores_attack_resistance_without_turning_into_aggression() -> void:
	_prepare()
	_fixed_terms(20)
	var resistance: C_DamageResistance = C_DamageResistance.new()
	_player.add_component(resistance)
	resistance.multipliers[DamageRequest.Type.GENERIC] = 0.0
	var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	assert_eq(_submit(record, true).reason, &"accepted")
	assert_eq(_health.current, 80.0)
	assert_null(CombatQueries.target_for(_dealer))
	assert_true(_person.memories.is_empty())
	assert_null(_probe.results[0].request.combat_context)
	assert_eq(_probe.results[0].request.origin_id, String(_person.npc_id))
#endregion


#region Closed record and full passive World restoration
func test_pending_and_accepted_receipts_restore_without_repeating_health_change() -> void:
	_prepare()
	var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	var key: StringName = record.confirmation_key
	var saved_person: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(_person)) as NpcRecord
	assert_true(BloodConsentRules.valid(saved_person))
	_district.people[0] = saved_person
	_person = saved_person
	assert_eq(BloodConsentService.offer(_player, _dealer).confirmation_key, key)
	assert_eq(_person.blood_offer_sequence, 2)
	assert_eq(_submit(record, true).reason, &"accepted")
	record = BloodConsentService.receipt_for(_dealer, key)
	var expected: float = 100.0 - record.applied_amount
	var snapshot: Dictionary = _snapshot()
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	_health.current = 100.0
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	_person = NpcPopulationQueries.person_for(_person.npc_id)
	_health = _player.get_component(C_Health) as C_Health
	record = BloodConsentService.receipt_for(_dealer, key)
	assert_not_null(record)
	assert_almost_eq(_health.current, expected, 0.00001)
	assert_eq(_submit(record, true).reason, &"accepted")
	assert_true(_submit(record, true).replayed)
	assert_almost_eq(_health.current, expected, 0.00001)
	assert_eq(_person.blood_offer_sequence, 2)


func test_malformed_history_and_previous_schema_reject_before_world_mutation() -> void:
	_prepare()
	var record: BloodConsentRecord = BloodConsentService.offer(_player, _dealer)
	assert_eq(_submit(record, true).reason, &"accepted")
	var current: float = _health.current
	var snapshot: Dictionary = _snapshot()
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for invalid: String in ["missing", "key", "owner", "percent", "amount", "pending", "sequence"]:
		var malformed: Dictionary = snapshot.duplicate(true)
		var fields: Dictionary = _encoded_person(malformed)
		var receipt: Dictionary = (fields.blood_offers as Array)[0].fields as Dictionary
		match invalid:
			"missing":
				receipt.erase("percent")
			"key":
				receipt.confirmation_key = &"other/key"
			"owner":
				receipt.dealer_id = &"npc/another"
			"percent":
				receipt.percent = 41
			"amount":
				receipt.applied_amount = 0.0
			"pending":
				receipt.outcome = BloodConsentRecord.Outcome.OFFERED
			"sequence":
				fields.blood_offer_sequence = 1
		assert_false(WorldSnapshotService.restore(malformed, _root), invalid)
		assert_same(NpcPopulationQueries.body_for(_person.npc_id), _dealer)
		assert_eq(_health.current, current)
	var previous: Dictionary = snapshot.duplicate(true)
	previous.version = 17
	assert_false(WorldSnapshotService.restore(previous, _root))
	assert_eq(_health.current, current)
#endregion
