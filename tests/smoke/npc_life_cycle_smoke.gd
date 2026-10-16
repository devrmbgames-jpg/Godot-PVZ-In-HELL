extends "res://tests/smoke/npc_authored_people_smoke.gd"
## Cold restart ожидающей личности, затем два возврата и отдельная партия каждой смерти.

const LIFE_SAVE_PATH: String = "user://npc_life_cycle_smoke.pvzh"
const STREET_DEATH_DISTANCE: float = 5.0


#region Production world and actual damage
func _make_world() -> World:
	return GameWorld.new()


func _save_path() -> String:
	return LIFE_SAVE_PATH


func _completion_prefix() -> String:
	return "NPC life smoke"


func _person_id() -> StringName:
	return &"npc/3"


func _create_world(world_seed: int) -> void:
	super._create_world(world_seed)
	var session: Entity = _world.query.with_all([C_District, C_DayCycle]).execute_one()
	session.add_component(C_LootDrops.new())
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HealthLifecycle.new())
	_world.add_observer(O_NpcRemains.new())
	for person: NpcRecord in NpcPopulationQueries.current().people:
		NpcPopulationQueries.body_for(person.npc_id).set_physics_process(false)


func _kill(person: NpcRecord) -> void:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var origin: StringName = person.home_id if person.profile.resident else person.portal_id
	var street: Vector3 = NpcPopulationQueries.position_for(origin, true) + Vector3(
		0,
		0,
		STREET_DEATH_DISTANCE * (person.deaths.size() + 1),
	)
	_check(
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"smoke_death",
			false,
			street,
		),
		"free street placement",
	)
	var request: DamageRequest = DamageRequest.new()
	request.target = body
	request.amount = (body.get_component(C_Health) as C_Health).value * 2.0
	DamageRequestService.submit(request)
	_check(body.has_component(C_Death), "real terminal damage")
	_check(person.death_day == DayPhaseQueries.current().day_index, "current death committed")
	_check(person.deaths.back().position == street, "own death position remembered")


func _morning(day: int) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = day
	cycle.phase = C_DayCycle.Phase.MORNING
	var receipt: DistrictMorningPreparationRequest = DistrictPopulationService.prepare_morning(day)
	_check(receipt.completed and receipt.succeeded, "prepared Morning %d" % day)
#endregion


#region Write and cold restore
func _write() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(_person_id())
	NpcDialogueMemoryService.set_tag(person, &"visited")
	NpcDialogueMemoryService.set_val(person, &"quest_stage", 4)
	_kill(person)
	_morning(2)
	_check(person.death_day == 1 and person.deaths.size() == 1, "day 2 remains absent")
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_check(WorldSnapshotService.can_restore(snapshot, _root), "absent authored snapshot")
	if not _failed:
		_check(AutosaveStore.write(snapshot, _save_path()) == OK, "isolated life snapshot write")


func _restore() -> void:
	var initial: NpcRecord = NpcPopulationQueries.person_for(_person_id())
	_check(initial.deaths.is_empty(), "new process starts without death history")
	var snapshot: Dictionary = AutosaveStore.read(_save_path())
	_check(not snapshot.is_empty(), "cold death snapshot read")
	_check(WorldSnapshotService.restore(snapshot, _root), "cold death snapshot restore")
	if _failed:
		return
	var person: NpcRecord = NpcPopulationQueries.person_for(_person_id())
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	_check(person.death_day == 1 and person.deaths.size() == 1, "death survived process exit")
	_check(person.deaths[0].returned_day == 0, "return not replayed early")
	var origin: StringName = person.home_id if person.profile.resident else person.portal_id
	_check(
		person.deaths[0].position == NpcPopulationQueries.position_for(origin, true)
		+ Vector3(0.0, 0.0, STREET_DEATH_DISTANCE),
		"nondefault death position survived process exit",
	)
	_check(person.deaths[0].known_actor_id.is_empty(), "environment did not reveal a killer")
	_check(person.deaths[0].suspected_actor_id.is_empty(), "environment did not invent suspicion")
	_check(not person.deaths[0].response_given, "pending personal response survived cold restore")
	_check(body.has_component(C_Death) and not body.enabled, "dead native participation")
	_check(GameTimeQueries.current().world_seed == WRITE_SEED, "saved clock retained")
	_check(LootDropService.current().committed_batches.size() == 1, "one persistent death batch")
	_morning(3)
	_check(person.death_day == 0 and person.deaths[0].returned_day == 3, "return on day 3")
	_check(NpcPopulationQueries.body_for(person.npc_id) == body, "same retained body returned")
	_kill(person)
	_check(person.deaths.size() == 2, "second actual death is a new episode")
	_check(LootDropService.current().committed_batches.size() == 2, "second distinct loot receipt")
	if _failed:
		return
	_morning(5)
	_check(person.deaths[1].returned_day == 5 and person.death_day == 0, "second calendar return")
	_check(person.dialogue_tags.get(&"visited", false), "old dialogue memory retained")
	_check(person.dialogue_values.get(&"quest_stage") == 4, "old quest progress retained")
	_check(NpcPopulationQueries.body_for(person.npc_id) == body, "no replacement native body")
	var district: C_District = NpcPopulationQueries.current()
	_check(
		NpcAuthoredPersonRules.matches(district.definition.person_for(person.npc_id), person),
		"authored identity retained across both lives",
	)
	_check(
		WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 5), _root),
		"returned second life has a valid current schema",
	)
#endregion
