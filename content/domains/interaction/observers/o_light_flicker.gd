extends Observer
## Проверяет тип события и ретранслирует запрос мерцания подписанным лампам.
class_name O_LightFlicker

## Проверенный запрос для ламп совпадающей цепи; STOP разрешён при выключенной цепи.
signal flickering_light(event: LightFlickerRequest)


## Подписывается на запросы мерцания сущностей световой цепи.
func query() -> QueryBuilder:
	return q.with_all([C_LightCircuit]).on_event(LightFlickerRequest.EVENT)


## Проверяет сущность, тип запроса и адрес цепи перед публикацией сигнала.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var request: LightFlickerRequest = payload as LightFlickerRequest
	if request == null or not EntityAvailability.contains(entity, _world):
		return

	var state: C_LightCircuit = entity.get_component(C_LightCircuit) as C_LightCircuit
	if state != null and state.circuit_id == request.circuit_id and (state.enabled or request.kind == LightFlickerRequest.Kind.STOP):
		flickering_light.emit(request)
