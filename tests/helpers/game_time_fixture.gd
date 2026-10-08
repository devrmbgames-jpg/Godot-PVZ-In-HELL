extends RefCounted
## Test-only level Clock/GamePlay/Storage execution; native physics keeps its callback delta.
class_name GameTimeFixture

#region Headless level execution
## Advances the gameplay slice and operational storage after one authoritative elapsed-clock step.
static func gameplay(world: World, delta: float) -> void:
	world.process(delta, "Clock")
	var gameplay_delta: float = GameTimeRules.seconds(GameTimeQueries.current().step_ticks)
	world.process(gameplay_delta, "GamePlay")
	world.process(delta, "Storage")


## Runs the full real-host group order while native physics retains its original callback delta.
static func frame(world: World, delta: float) -> void:
	world.process(delta, "Clock")
	var gameplay_delta: float = GameTimeRules.seconds(GameTimeQueries.current().step_ticks)
	world.process(gameplay_delta, "Input")
	world.process(gameplay_delta, "Interaction")
	world.process(delta, "Physics")
	world.process(gameplay_delta, "GamePlay")
	world.process(delta, "Storage")
#endregion
