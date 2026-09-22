extends Node


func _ready() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	add_child(level)
	for frame_index: int in 8:
		await get_tree().process_frame
	var cycle: C_DayCycle = S_DayPhase.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(S_DayPhase.submit(request))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var save_error: Error = screenshot.save_png("res://tests/artifacts/hud_preview.png")
	assert(save_error == OK)
	print("HUD preview saved")
	get_tree().quit()
