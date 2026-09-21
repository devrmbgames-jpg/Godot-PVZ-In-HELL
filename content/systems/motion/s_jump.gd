extends System
class_name S_Jump


func query() -> QueryBuilder:
	return q.with_all(
		[C_Jump, C_Controller]
	).iterate([C_Jump, C_Controller])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var jumps: Array = components[0]
	var controllers: Array = components[1]
	for idx in entities.size() :
		var c_jump: C_Jump = jumps[idx]
		var c_controller: C_Controller = controllers[idx]
		c_jump.active = c_controller.action_jump
		
