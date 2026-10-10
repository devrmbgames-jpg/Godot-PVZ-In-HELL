extends RefCounted
## Offline before/after composition evidence and representative construction timing.

const _BOX_PATH: String = "res://content/domains/interaction/entities/box.tscn"


#region Detached comparison and timing
## Writes reproducible detached plans and construction timings to the requested output file.
func run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var preview: GDScript = load(
		"res://content/editor/entity_authoring/entity_authoring_preview_rules.gd"
	) as GDScript
	var paths: Array[String] = [
		"res://content/scenes/main_level.tscn",
		"res://tests/fixtures/refactoring_v2/authoring_level.tscn",
		"res://content/domains/packages/entities/package.tscn",
		"res://content/domains/interaction/entities/physical_slot.tscn",
		"res://content/domains/customers/entities/customer.tscn",
	]
	var reports: Dictionary = { }
	for scene_path: String in paths:
		var scene: PackedScene = load(scene_path) as PackedScene
		var actor: Node = scene.instantiate()
		reports[scene_path] = preview.call("inspect_scene", actor)
		actor.free()
	var box: PackedScene = load(_BOX_PATH) as PackedScene
	var compile_samples: Array[int] = []
	var register_samples: Array[int] = []
	for sample: int in 3:
		compile_samples.append(_measure_compile(box))
		register_samples.append(_measure_registration(box))
	reports["compile_500_samples"] = compile_samples
	reports["register_500_samples"] = register_samples
	compile_samples.sort()
	register_samples.sort()
	reports["compile_500_usec"] = compile_samples[1]
	reports["register_500_usec"] = register_samples[1]
	var output: FileAccess = FileAccess.open(arguments[0], FileAccess.WRITE)
	output.store_string(JSON.stringify(reports, "\t"))
	print("Audit: %d scenes; 500 builds: %d usec" % [paths.size(), reports["compile_500_usec"]])
	print("Audit: 500 registrations: %d usec" % reports["register_500_usec"])


func _measure_compile(box: PackedScene) -> int:
	var start: int = Time.get_ticks_usec()
	for index: int in 500:
		var actor: Entity = box.instantiate() as Entity
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			null,
			"bench/%d" % index,
		)
		var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
		assert(plan.valid())
		actor.free()
	return Time.get_ticks_usec() - start


func _measure_registration(box: PackedScene) -> int:
	var world: World = World.new()
	var start: int = Time.get_ticks_usec()
	for index: int in 500:
		var actor: Entity = box.instantiate() as Entity
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			world,
			"register/%d" % index,
		)
		var registered: bool = EntityCompositionService.try_register(context, false)
		assert(registered)
	var elapsed: int = Time.get_ticks_usec() - start
	world.purge(false)
	world.free()
	return elapsed
#endregion
