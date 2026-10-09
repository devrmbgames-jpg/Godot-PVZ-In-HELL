extends GutTest
## Repeats real GUT fixture lifecycles and samples only after deferred cleanup settles.

const SCENARIO_ROOT: String = "res://tests/fixtures/memory_lifecycle_scenarios/"
const DEFAULT_WARMUP: int = 12
const DEFAULT_CYCLES: int = 60
const ACK_TIMEOUT_MS: int = 10000

var _failures: int = 0
var _assertions: int = 0
var _sample_token: int = 0
var _ack_path: String = ""


#region Measurement orchestration
## Runs measured lifecycle scenarios inside one native GUT process.
func test_memory_lifecycle() -> void:
	_ack_path = OS.get_environment("PVZ_MEMORY_ACK")
	await _run()
	assert_eq(_failures, 0, "Every repeated functional fixture and sampler must succeed")
	assert_gt(_assertions, 0, "Repeated fixtures must execute their assertions")


func _run() -> void:
	var warmup: int = _iterations("PVZ_MEMORY_WARMUP", DEFAULT_WARMUP)
	var cycles: int = _iterations("PVZ_MEMORY_CYCLES", DEFAULT_CYCLES)
	var scenarios: Array[Dictionary] = [
		{
			"name": "persistent_inspection",
			"fixture": "test_customer_inspection.gd",
			"method": "",
			"persistent": true,
		},
		{
			"name": "persistent_world_entities",
			"fixture": "test_s_grab.gd",
			"method": "",
			"persistent": true,
		},
		{
			"name": "persistent_world_proxies",
			"fixture": "test_s_grab.gd",
			"method": "test_scriptless_body_removal_cleans_runtime_proxy_and_holder",
			"persistent": true,
		},
		{ "name": "entity_create_remove", "fixture": "", "method": "" },
		{ "name": "world_restart", "fixture": "test_district_population.gd", "method": "" },
		{
			"name": "npc_spawn_despawn",
			"fixture": "test_district_population.gd",
			"method": "test_departure_and_return_keep_body_health_and_memory",
		},
		{
			"name": "customer_spawn_handoff",
			"fixture": "test_customer_handoff.gd",
			"method": (
				"test_waiting_customer_takes_correct_carry_once_"
				+ "without_button_or_greeting_delay"
			),
		},
		{ "name": "physical_create_remove", "fixture": "test_s_grab.gd", "method": "" },
		{
			"name": "grab_drop",
			"fixture": "test_s_grab.gd",
			"method": "test_interact_picks_up_and_releases_with_load_and_collision_cleanup",
		},
		{
			"name": "proxy_grab_delete",
			"fixture": "test_s_grab.gd",
			"method": "test_scriptless_body_removal_cleans_runtime_proxy_and_holder",
		},
		{
			"name": "cargo_deferred",
			"fixture": "test_s_grab.gd",
			"method": "test_cart_cargo_manual_flush_rejects_previous_physics_frame",
		},
		{
			"name": "loot_create_remove",
			"fixture": "test_npc_remains.gd",
			"method": "test_actual_death_creates_three_edible_pieces_and_guaranteed_medkit_once",
		},
		{
			"name": "save_load_restore",
			"fixture": "test_district_snapshot.gd",
			"method": "test_absent_person_roundtrip_preserves_body_state_and_resets_brain",
		},
	]
	var selected: String = OS.get_environment("PVZ_MEMORY_SCENARIO")
	for scenario: Dictionary in scenarios:
		if not selected.is_empty() and scenario.name != selected:
			continue
		var resident: GutTest = null
		if bool(scenario.get("persistent", false)):
			var resident_script: Script = load(SCENARIO_ROOT + String(scenario.fixture)) as Script
			resident = resident_script.new() as GutTest
			add_child(resident)
			await resident.before_each()
		for iteration: int in warmup:
			await _cycle(scenario, resident)
			await _settle()

		await _sample(scenario.name, 0)
		for iteration: int in cycles:
			await _cycle(scenario, resident)
			await _settle()
			await _sample(scenario.name, iteration + 1)
		if resident != null:
			await resident.after_each()
			resident.queue_free()
			await _settle()
		print("MEMORY_SCENARIO_DONE ", scenario.name)
	print(
		"MEMORY_RESULT ",
		JSON.stringify(
			{ "failures": _failures, "assertions": _assertions, "cycles": cycles, "warmup": warmup }
		),
	)


func _iterations(variable_name: String, fallback: int) -> int:
	var configured: String = OS.get_environment(variable_name)
	return int(configured) if not configured.is_empty() else fallback
#endregion


#region Real operation and fixture ownership
func _cycle(scenario: Dictionary, resident: GutTest = null) -> void:
	if resident != null:
		if scenario.name == "persistent_inspection":
			_inspection_cycle(resident)
		elif scenario.name == "persistent_world_entities":
			await _entity_in_world(resident.get("grab_world") as World)
		else:
			var previous: Dictionary = (resident.get_summary() as Dictionary).duplicate()
			await resident.call(String(scenario.method))
			var current: Dictionary = resident.get_summary() as Dictionary
			_failures += int(current.failed) - int(previous.failed)
			_assertions += int(current.asserts) - int(previous.asserts)
			if int(current.failed) > int(previous.failed):
				print("MEMORY_FUNCTIONAL_FAILURE ", resident.get_summary_text())
			# Preserve totals and failures in host logs, release the test's per-assertion strings.
			(resident.get("_fail_pass_text") as Array).clear()
		return
	if scenario.fixture == "":
		await _entity_cycle()
		return

	# Each GutTest owns its temporary assertion strings; disposing it bounds harness memory.
	# No running GutMain receives per-assertion records, which would itself grow every cycle.
	var fixture_script: Script = load(SCENARIO_ROOT + String(scenario.fixture)) as Script
	var fixture: GutTest = fixture_script.new() as GutTest
	add_child(fixture)
	await fixture.before_each()
	if scenario.method != "":
		await fixture.call(String(scenario.method))
	else:
		_assertions += 1
		if scenario.name == "world_restart":
			var population: C_District = NpcPopulationQueries.current()
			if population == null or population.people.size() != 12:
				_failures += 1
		elif scenario.name == "physical_create_remove":
			var physical_world: World = fixture.get("grab_world") as World
			if physical_world == null or physical_world.entities.size() != 2:
				_failures += 1
	if scenario.name == "save_load_restore":
		_disk_roundtrip(fixture.get("_root") as Node)

	await fixture.after_each()
	var summary: Dictionary = fixture.get_summary() as Dictionary
	_failures += int(summary.failed)
	_assertions += int(summary.asserts)
	if int(summary.failed) > 0:
		print("MEMORY_FUNCTIONAL_FAILURE ", fixture.get_summary_text())
	fixture.queue_free()


func _entity_cycle() -> void:
	var world: World = World.new()
	add_child(world)
	ECS.world = world
	await _entity_in_world(world)
	world.purge(false)
	ECS.world = null
	world.queue_free()


func _entity_in_world(world: World) -> void:
	var actor: Entity = Entity.new()
	actor.component_resources = [C_Health.new()]
	var bridge_path: String = "res://tests/helpers/entity_composition_fixture.gd"
	if FileAccess.file_exists(bridge_path):
		var bridge: Script = load(bridge_path) as Script
		bridge.call("register", world, actor)
	else:
		world.add_entity(actor)
	var retired: WeakRef = weakref(actor)
	world.remove_entity(actor)
	await _settle()
	_assertions += 1
	if retired.get_ref() != null:
		_failures += 1


func _disk_roundtrip(world_root: Node) -> void:
	var path: String = "user://memory_lifecycle_%d.pvzh" % OS.get_process_id()
	var snapshot: Dictionary = WorldSnapshotService.capture(world_root, 2)
	var write_error: Error = AutosaveStore.write(snapshot, path)
	var restored: Dictionary = AutosaveStore.read(path)
	var accepted: bool = write_error == OK and WorldSnapshotService.restore(restored, world_root)
	_assertions += 1
	if not accepted:
		_failures += 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _inspection_cycle(fixture: GutTest) -> void:
	var customer: E_NpcCharacter = fixture.get("_customer") as E_NpcCharacter
	var visit: CustomerVisit = fixture.get("_visit") as CustomerVisit
	var parcel: Entity = fixture.get("_parcel") as Entity
	var started: bool = CustomerInspectionService.begin(customer, visit, parcel)
	CustomerInspectionService.end(customer)
	_assertions += 3
	if not started or CustomerInspectionQueries.owner_for(parcel) != null \
			or not CustomerInspectionQueries.cargo(customer).is_empty():
		_failures += 1
#endregion


#region Quiescent sampling and native process handshake
func _settle() -> void:
	# Two physics and idle boundaries finish queue_free, deferred signals and native release.
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _sample(scenario_name: String, iteration: int) -> void:
	_sample_token += 1
	var sample: Dictionary = {
		"scenario": scenario_name,
		"iteration": iteration,
		"token": _sample_token,
		"pid": OS.get_process_id(),
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
	}
	print("MEMORY_SAMPLE ", JSON.stringify(sample))
	if _ack_path.is_empty():
		return

	# Hold the next operation until the host captures RSS/Private Bytes at this exact boundary.
	var deadline: int = Time.get_ticks_msec() + ACK_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if FileAccess.file_exists(_ack_path):
			var acknowledged: String = FileAccess.get_file_as_string(_ack_path)
			if acknowledged == str(_sample_token):
				return
	_failures += 1
	push_error("Memory sampler did not acknowledge the quiescent measurement")
#endregion
