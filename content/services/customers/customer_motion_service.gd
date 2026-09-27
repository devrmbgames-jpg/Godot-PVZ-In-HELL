extends RefCounted
class_name CustomerMotionService


static func step(customer: E_Customer, delta: float) -> void:
	var body: CharacterBody3D = customer as Node as CharacterBody3D
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or body == null:
		return
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit == null:
		return
	var direction: Vector3 = agent.destination - body.global_position
	direction.y = 0.0
	agent.arrived = direction.length() <= visit.definition.arrival_distance
	var speed: float = visit.definition.move_speed if agent.moving and not agent.arrived else 0.0
	var horizontal: Vector3 = direction.normalized() * speed
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z
	if not body.is_on_floor():
		body.velocity.y -= visit.definition.gravity * delta
	else:
		body.velocity.y = 0.0
	body.move_and_slide()
