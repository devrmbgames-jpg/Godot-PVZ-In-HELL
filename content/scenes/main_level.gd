extends Node3D


@export var world: World = null


func _physics_process(delta: float) -> void:
	if not world : return
	world.process(delta, "Physics")
	world.process(delta, "GamePlay")

func _process(delta: float) -> void:
	if not world : return
	world.process(delta, "Input")
