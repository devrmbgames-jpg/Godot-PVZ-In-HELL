extends RefCounted
## Test-only World execution of real AI owners; no legacy Service scheduling aliases.
class_name NpcAiFixture

## Isolated World group used only for real-owner fixture execution.
const GROUP: String = "npc_ai_fixture"

#region Real owner execution
## Advances the complete production cadence/sensing/trait/native-decision/noise dependency graph.
static func advance(_district: C_District, delta: float) -> void:
	_run([S_NpcCadence, S_NpcFootsteps, S_NpcPerception, S_NpcTraits, S_NpcDecision, S_NpcNoise], delta)


## Runs actual sensing in isolation so geometry assertions do not advance unrelated trait clocks.
static func sense(body: E_DistrictNpc, person: NpcRecord, player: Entity, delta: float) -> void:
	_select_only(body, person, delta)
	if player != null and not player.has_component(C_PlayerInputController):
		player.add_component(C_PlayerInputController.new())
	_run([S_NpcPerception], 0.0)


## Runs the actual exposure owner against the already sampled awareness used by the test.
static func traits(body: E_DistrictNpc, person: NpcRecord, player: Entity, delta: float) -> void:
	_select_only(body, person, delta)
	if player != null and not player.has_component(C_PlayerInputController):
		player.add_component(C_PlayerInputController.new())
	_run([S_NpcTraits], 0.0)


## Runs the actual footstep clock for the selected body or the fixture player.
static func footsteps(body: Entity, delta: float) -> void:
	_clear_due()
	if body.has_component(C_NpcIdentity) and not body.has_component(C_PlayerInputController):
		var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
		_select_only(body as E_DistrictNpc, DistrictPopulationService.person_for(identity.npc_id), delta)
	_run([S_NpcFootsteps], delta)
#endregion

#region Isolated due-step setup
static func _clear_due() -> void:
	for entity: Entity in ECS.world.query.with_all([C_NpcDecision]).execute():
		(entity.get_component(C_NpcDecision) as C_NpcDecision).scheduled_delta = 0.0


static func _select_only(body: E_DistrictNpc, person: NpcRecord, delta: float) -> void:
	_clear_due()
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	if person.npc_id.is_empty():
		person.npc_id = StringName("fixture/npc/%d" % body.get_instance_id())
		identity.npc_id = person.npc_id
		person.placement = NpcRecord.Placement.STREET
		DistrictPopulationService.current().people.append(person)
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var cycle: C_DayCycle = DayPhaseService.current()
	decision.scheduled_delta = delta
	decision.scheduled_day = cycle.day_index
	decision.scheduled_phase = int(cycle.phase)


static func _run(owner_types: Array[Script], delta: float) -> void:
	var owners: Array[System] = []
	for owner_type: Script in owner_types:
		var owner: System = owner_type.new() as System
		owner.group = GROUP
		owners.append(owner)
	ECS.world.add_systems(owners, true)
	ECS.world.process(delta, GROUP)
	for owner: System in owners:
		ECS.world.remove_system(owner)
#endregion
