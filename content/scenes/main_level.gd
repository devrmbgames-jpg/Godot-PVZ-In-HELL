extends Node3D

@export var world: World = null


func _ready() -> void:
	ECS.world = world
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if world == null:
		return
	world.process(delta, "Input")
	world.process(delta, "Interaction")
	world.process(delta, "Physics")
	world.process(delta, "GamePlay")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"menu"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
