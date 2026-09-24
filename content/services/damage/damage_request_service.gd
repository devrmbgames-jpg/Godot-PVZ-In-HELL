extends RefCounted
## Single typed event entry point for damage producers; O_Damage owns HP arithmetic.
class_name DamageRequestService


## Publishes an owned snapshot; null targets must never become a World broadcast.
static func submit(request: DamageRequest) -> bool:
	if request == null or not EntityAvailability.contains(request.target, ECS.world):
		return false
	if not request.target.has_component(C_Health):
		return false
	var snapshot: DamageRequest = DamageRequest.new()
	snapshot.target = request.target
	snapshot.source = request.source
	snapshot.instigator = request.instigator
	snapshot.origin_id = request.origin_id
	snapshot.instigator_id = request.instigator_id
	snapshot.amount = request.amount
	snapshot.operation = request.operation
	snapshot.damage_type = request.damage_type
	ECS.world.emit_event(DamageRequest.EVENT, snapshot.target, snapshot)
	return true

## Фабричный вариант сборки запроса, опционально, но не рекомендую


static func create_request() -> DamageRequestBuilder:
	return DamageRequestBuilder.new()


class DamageRequestBuilder:
	var request := DamageRequest.new()


	func with_instigator(e: Entity) -> DamageRequestBuilder:
		request.instigator = e
		return self


	func with_source(e: Entity) -> DamageRequestBuilder:
		request.source = e
		return self


	func with_target(e: Entity) -> DamageRequestBuilder:
		request.target = e
		return self


	func with_amount(v: float) -> DamageRequestBuilder:
		request.amount = v
		return self


	func with_operation(o: DamageRequest.Operation) -> DamageRequestBuilder:
		request.operation = o
		return self


	func with_damage_type(d: DamageRequest.Type) -> DamageRequestBuilder:
		request.damage_type = d
		return self


	## Uses the same validation and snapshot path as ordinary producers.
	func submit() -> bool:
		var submitted: bool = DamageRequestService.submit(request)
		request = null
		return submitted
