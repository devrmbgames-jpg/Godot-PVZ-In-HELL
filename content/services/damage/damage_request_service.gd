extends RefCounted
class_name DamageRequestService





static func submit(request: DamageRequest) -> bool :
	if request == null or not is_instance_valid(ECS.world):
		return false
	
	ECS.world.emit_event(
		DamageRequest.EVENT,
		request.target,
		request
	)
	return true

## Фабричный вариант сборки запроса, опционально, но не рекомендую

static func create_request() -> DamageRequestBuilder :
	return DamageRequestBuilder.new()

class DamageRequestBuilder :
	var request := DamageRequest.new()
	
	func with_instigator(e: Entity) -> DamageRequestBuilder :
		request.instigator = e
		return self
	
	func with_source(e: Entity) -> DamageRequestBuilder :
		request.source = e
		return self
	
	func with_target(e: Entity) -> DamageRequestBuilder :
		request.target = e
		return self
	
	func with_amount(v: float) -> DamageRequestBuilder :
		request.amount = v
		return self
	
	func with_operation(o: DamageRequest.Operation) -> DamageRequestBuilder :
		request.operation = o
		return self
	
	func with_damage_type(d: DamageRequest.Type) -> DamageRequestBuilder :
		request.damage_type = d
		return self
	
	
	func submit() -> bool :
		if request :
			ECS.world.emit_event(
				DamageRequest.EVENT,
				request.target,
				request
			)
			request = null
			return true
		return false
