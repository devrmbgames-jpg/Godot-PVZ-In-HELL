extends "res://tests/gut/test_district_population.gd"
## Native soul transactions, idempotent receipts, common depletion and closed snapshot restoration.

const PLAYER: PackedScene = preload(
	"res://content/domains/motion/entities/character_body_player.tscn"
)
const CHAIN: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_chain_devil.tres"
)

var _original_profile: DEF_NpcArchetype = null
var _original_variation: NpcVariation = null
var _player: Entity = null
var _dealer: E_DistrictNpc = null
var _health: C_Health = null
var _strength: C_Strength = null
var _ledger: C_SoulTrade = null
var _results: SoulResultProbe = null
var _health_probe: SoulResultProbe = null


## Records committed facts and can retire the receiver at its genuine publication boundary.
class SoulResultProbe extends Observer:
	var received: Array[SoulTradeResult] = []
	var event_name: StringName = SoulTradeResult.EVENT
	var retire_on_health: bool = false
	var health_results: Array[DamageResult] = []


	#region Publication fixture
	func query() -> QueryBuilder:
		return q.with_all([C_SoulTrade]).on_event(event_name)


	func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
		if event == DamageResult.EVENT:
			health_results.append(payload as DamageResult)
			if retire_on_health:
				cmd.add_custom(_retire.bind(entity))
		else:
			received.append(payload as SoulTradeResult)


	func _retire(entity: Entity) -> void:
		_world.remove_entity(entity)
		entity.free()
	#endregion


#region Real player and dealer fixture
func _prepare_trade() -> void:
	var person: NpcRecord = _district.people[0]
	_original_profile = person.profile
	_original_variation = person.variation
	person.profile = CHAIN
	person.variation = NpcVariationRules.create(CHAIN, 1234, person.npc_id, 1)
	_dealer = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, _dealer, NpcRecord.Placement.STREET)
	_dealer.place_at(NpcPopulationQueries.position_for(person.home_id))
	_player = PLAYER.instantiate() as Entity
	_player.id = "soul/player"
	EntityCompositionFixture.register(_world, _player)
	(_player as Node as Node3D).global_position = _dealer.global_position + Vector3.FORWARD
	(_player as Node).set_physics_process(false)
	_health = _player.get_component(C_Health) as C_Health
	_strength = _player.get_component(C_Strength) as C_Strength
	_ledger = _player.get_component(C_SoulTrade) as C_SoulTrade
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HealthLifecycle.new())
	_results = SoulResultProbe.new()
	_world.add_observer(_results)
	_health_probe = SoulResultProbe.new()
	_health_probe.event_name = DamageResult.EVENT
	_world.add_observer(_health_probe)
	assert_true(NpcDialogueService.begin(_player, _dealer, true))


func _resolve(record: SoulTradeRecord, accept: bool) -> SoulTradeResult:
	var request: SoulTradeRequest = SoulTradeRequest.new()
	request.actor = _player
	request.dealer = _dealer
	request.confirmation_key = record.confirmation_key
	request.accept = accept
	return SoulTradeService.submit(request)


func _next_offer() -> SoulTradeRecord:
	var record: SoulTradeRecord = _ledger.offers.back()
	GameTimeQueries.current().elapsed_ticks = record.next_offer_tick
	return SoulTradeService.offer(_player, _dealer)
#endregion


#region Authoritative effects and durable replay
func test_fatal_policy_boundaries_reject_invalid_offers_without_touching_ledger() -> void:
	_prepare_trade()
	var person: NpcRecord = _district.people[0]
	person.profile = CHAIN.duplicate(true) as DEF_NpcArchetype
	var shared: DEF_NpcSoulTrade = SoulTradeService.rule_for(_dealer)
	var rule: DEF_NpcSoulTrade = shared.duplicate() as DEF_NpcSoulTrade
	person.profile.rules[person.profile.rules.find(shared)] = rule
	for invalid: int in [0, 101]:
		rule.fatal_deal_count = invalid
		assert_false(rule.valid_configuration())
		assert_false(SoulTradeService.available(_player, _dealer))
		assert_null(SoulTradeService.offer(_player, _dealer))
		assert_true(_ledger.offers.is_empty())
		assert_eq(_ledger.next_sequence, 1)
	for valid: int in [1, 100]:
		rule.fatal_deal_count = valid
		assert_true(rule.valid_configuration())
		var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
		assert_not_null(record)
		if record == null:
			continue
		assert_eq(record.fatal_deal_count, valid)
		assert_true(SoulTradeRules.valid(_ledger))
		assert_eq(_resolve(record, false).reason, &"declined")
		GameTimeQueries.current().elapsed_ticks = record.next_offer_tick


func test_accept_commits_stats_and_receipt_once_before_property_callbacks() -> void:
	_prepare_trade()
	var snapshots: Array[Vector3] = []
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	_health.property_changed.connect(
		func(_component: Resource, _key: StringName, _old: Variant, _new: Variant) -> void:
			snapshots.append(Vector3(_strength.value, _health.value, _health.current))
			assert_eq(_ledger.accepted_count, 1)
			assert_true(_resolve(record, true).replayed),
	)
	var result: SoulTradeResult = _resolve(record, true)
	assert_eq(result.reason, &"accepted")
	assert_false(result.replayed)
	assert_eq(_strength.base, 2.0)
	assert_eq(_strength.value, 2.0)
	assert_eq(_health.base, 90.0)
	assert_eq(_health.value, 90.0)
	assert_eq(_health.current, 90.0)
	assert_eq(_ledger.accepted_count, 1)
	assert_false(_player.has_component(C_Death))
	assert_false(snapshots.is_empty())
	for snapshot: Vector3 in snapshots:
		assert_eq(snapshot, Vector3(2.0, 90.0, 90.0))
	assert_eq(_results.received.size(), 1)
	assert_eq(_health_probe.health_results.size(), 1)
	assert_true(_resolve(record, false).replayed)
	assert_eq(_health.current, 90.0)
	assert_true(SoulTradeRules.valid(_ledger))


func test_decline_never_resets_total_and_third_accepted_deal_causes_common_death() -> void:
	_prepare_trade()
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	assert_eq(_resolve(record, true).reason, &"accepted")
	record = _next_offer()
	assert_eq(_resolve(record, false).reason, &"declined")
	assert_eq(_ledger.accepted_count, 1)
	assert_eq(_strength.value, 2.0)
	assert_eq(_health.value, 90.0)
	record = _next_offer()
	assert_eq(_resolve(record, true).reason, &"accepted")
	assert_eq(_ledger.accepted_count, 2)
	assert_false(_player.has_component(C_Death))
	record = _next_offer()
	var immunity: C_DamageResistance = C_DamageResistance.new()
	immunity.multipliers[DamageRequest.Type.GENERIC] = 0.0
	_player.add_component(immunity)
	assert_eq(_resolve(record, true).reason, &"accepted")
	assert_eq(_ledger.accepted_count, 3)
	assert_true(record.fatal)
	assert_eq(_strength.value, 4.0)
	assert_eq(_health.value, 70.0)
	assert_eq(_health.current, 0.0)
	assert_true(_health.depleted)
	assert_true(_player.has_component(C_Death))
	assert_true(_resolve(record, true).replayed)
	assert_true(SoulTradeRules.valid(_ledger))


func test_closure_retains_pending_key_and_saved_simulation_cooldown() -> void:
	_prepare_trade()
	var before: int = GameTimeQueries.current().elapsed_ticks
	assert_true(SoulTradeService.available(_player, _dealer))
	assert_true(_ledger.offers.is_empty())
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	NpcDialogueService.end(_dealer)
	assert_false(SoulTradeService.available(_player, _dealer))
	assert_true(NpcDialogueService.begin(_player, _dealer))
	assert_same(SoulTradeService.offer(_player, _dealer), record)
	assert_eq(_ledger.accepted_count, 0)
	assert_eq(_resolve(record, false).reason, &"declined")
	assert_gt(record.next_offer_tick, before)
	assert_false(SoulTradeService.available(_player, _dealer))
	GameTimeQueries.current().elapsed_ticks = record.next_offer_tick - 1
	assert_false(SoulTradeService.available(_player, _dealer))
	GameTimeQueries.current().elapsed_ticks += 1
	assert_true(SoulTradeService.available(_player, _dealer))
	var next: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	assert_ne(next.confirmation_key, record.confirmation_key)
	assert_eq(_ledger.offers.size(), 2)


func test_captured_terms_survive_authored_changes_and_low_current_health_is_not_healed() -> void:
	_prepare_trade()
	_health.current = 20.0
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	var person: NpcRecord = _district.people[0]
	person.profile = CHAIN.duplicate(true) as DEF_NpcArchetype
	var shared: DEF_NpcSoulTrade = SoulTradeService.rule_for(_dealer)
	var rule: DEF_NpcSoulTrade = shared.duplicate() as DEF_NpcSoulTrade
	person.profile.rules[person.profile.rules.find(shared)] = rule
	rule.strength_gain = 5.0
	rule.maximum_health_cost = 30.0
	assert_eq(_resolve(record, true).reason, &"accepted")
	assert_eq(_strength.value, 2.0)
	assert_eq(_health.value, 90.0)
	assert_eq(_health.current, 20.0)
	assert_eq(record.strength_gain, 1.0)
	assert_eq(record.maximum_health_cost, 10.0)


func test_invalid_target_or_confirmation_cannot_commit_any_partial_effect() -> void:
	_prepare_trade()
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	var request: SoulTradeRequest = SoulTradeRequest.new()
	request.actor = _player
	request.dealer = _dealer
	request.confirmation_key = &"soul/forged"
	request.accept = true
	assert_null(SoulTradeService.submit(request).receipt)
	_health.value = 10.0
	_health.base = 10.0
	_health.current = 10.0
	assert_eq(_resolve(record, true).reason, &"invalid_attributes")
	assert_eq(record.outcome, SoulTradeRecord.Outcome.OFFERED)
	assert_eq(_ledger.accepted_count, 0)
	assert_eq(_strength.value, 1.0)
	assert_eq(_health.current, 10.0)
	assert_eq(_results.received.size(), 0)


func test_committed_stat_publication_can_retire_player_without_stale_access() -> void:
	_prepare_trade()
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	_health_probe.retire_on_health = true
	var result: SoulTradeResult = _resolve(record, true)
	assert_eq(result.reason, &"accepted")
	assert_eq(record.outcome, SoulTradeRecord.Outcome.ACCEPTED)
	assert_eq(_ledger.accepted_count, 1)
	assert_eq(_health.value, 90.0)
	assert_eq(_strength.value, 2.0)
	assert_false(is_instance_valid(_player))
	_player = null
#endregion


#region Closed codec and full World restore
func test_missing_required_stats_or_ledger_and_foreign_receipts_reject_before_mutation() -> void:
	_prepare_trade()
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	assert_eq(_resolve(record, true).reason, &"accepted")
	_district.people[0].profile = _original_profile
	_district.people[0].variation = _original_variation
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for required: Script in [C_Strength, C_SoulTrade]:
		var damaged: Dictionary = snapshot.duplicate(true)
		for entry: Dictionary in damaged.entities:
			if entry.entity_id != _player.id:
				continue
			var retained: Array = []
			for component: Dictionary in entry.components:
				if component.type != required.resource_path:
					retained.append(component)
			entry.components = retained
		assert_false(WorldSnapshotService.restore(damaged, _root))
		assert_eq(_ledger.accepted_count, 1)
		assert_eq(_strength.value, 2.0)
	var foreign: Dictionary = snapshot.duplicate(true)
	for entry: Dictionary in foreign.entities:
		for component: Dictionary in entry.components:
			if component.type != C_SoulTrade.resource_path:
				continue
			var encoded: Dictionary = (component.fields.offers as Array)[0] as Dictionary
			encoded.fields.actor_id = "other/player"
			encoded.fields.confirmation_key = &"soul/other/player/1"
	assert_false(WorldSnapshotService.restore(foreign, _root))
	assert_eq(_ledger.accepted_count, 1)
	assert_eq(_health.value, 90.0)


func test_world_restore_preserves_stat_cost_count_key_and_does_not_repeat_confirmation() -> void:
	_prepare_trade()
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	assert_eq(_resolve(record, true).reason, &"accepted")
	var key: StringName = record.confirmation_key
	_district.people[0].profile = _original_profile
	_district.people[0].variation = _original_variation
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	_strength.value = 99.0
	_health.value = 100.0
	_health.current = 100.0
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	_health = _player.get_component(C_Health) as C_Health
	_strength = _player.get_component(C_Strength) as C_Strength
	_ledger = _player.get_component(C_SoulTrade) as C_SoulTrade
	record = SoulTradeService.receipt_for(_player, key)
	assert_not_null(record)
	assert_eq(_health.value, 90.0)
	assert_eq(_strength.value, 2.0)
	assert_eq(_ledger.accepted_count, 1)
	var result: SoulTradeResult = _resolve(record, true)
	assert_true(result.replayed)
	assert_eq(_strength.value, 2.0)
	assert_false(SoulTradeService.available(_player, _dealer))


func test_malformed_ledger_and_previous_schema_reject_before_live_mutation() -> void:
	_prepare_trade()
	var record: SoulTradeRecord = SoulTradeService.offer(_player, _dealer)
	assert_eq(_resolve(record, true).reason, &"accepted")
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	for entry: Dictionary in snapshot.entities:
		for component: Dictionary in entry.components:
			if component.type == C_SoulTrade.resource_path:
				component.fields.accepted_count = 0
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_ledger.accepted_count, 1)
	assert_eq(_strength.value, 2.0)
	snapshot = WorldSnapshotService.capture(_root, 1)
	snapshot.version = AutosaveStore.SCHEMA_VERSION - 1
	assert_false(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_health.value, 90.0)
	var data: Dictionary = SaveDataCodec.component_data(_ledger)
	var encoded: Dictionary = (data.fields.offers as Array)[0] as Dictionary
	(encoded.fields as Dictionary).erase("confirmation_key")
	assert_false(SaveDataCodec.apply_fields(C_SoulTrade.new(), data.fields as Dictionary))
#endregion
