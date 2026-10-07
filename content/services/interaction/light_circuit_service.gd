extends RefCounted
## C_LightCircuit владеет состоянием цепи, авторские группы Light3D показывают его.
class_name LightCircuitService

static var _lookup_world: World = null
static var _circuit_query: QueryBuilder = null
static var _circuit_references: Dictionary[StringName, WeakRef] = {}

#region Действия световой цепи
## Задаёт enabled доступной световой цепи и синхронизирует её представление.
static func set_enabled(circuit: Entity, enabled: bool) -> bool:
	if not EntityAvailability.contains(circuit, ECS.world):
		return false

	var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
	if state == null:
		return false

	state.enabled = enabled
	sync(circuit, state)
	return true

## Применяет состояние цепи к авторским группам света; выключение прекращает мерцание.
static func sync(circuit: Entity, state: C_LightCircuit) -> void:
	if state == null:
		return

	for group_id: StringName in state.light_groups:
		for node: Node in circuit.get_tree().get_nodes_in_group(group_id):
			var light: Light3D = node as Light3D
			if light != null:
				var view: CircuitLightView = light.get_node_or_null("CircuitLightView") as CircuitLightView
				if view != null and not state.enabled:
					view.cancel_flicker()
				light.visible = state.enabled and (view == null or view.is_lit())

## Публикует временное мерцание: duration и interval в секундах, enabled цепи не меняется.
static func flicker(circuit_id: StringName, duration: float, interval: float, request_id: StringName = &"") -> bool:
	var circuit: Entity = entity_for(circuit_id)
	if circuit == null or not is_enabled(circuit_id) or not is_finite(duration) or duration <= 0.0 or not is_finite(interval) or interval <= 0.0:
		return false

	var event: LightFlickerRequest = LightFlickerRequest.new()
	event.request_id = request_id
	event.circuit_id = circuit_id
	event.duration_seconds = duration
	event.interval_seconds = interval
	ECS.world.emit_event(LightFlickerRequest.EVENT, circuit, event)
	return true

## Останавливает визуальный запрос мерцания по circuit_id и request_id.
static func stop_flicker(circuit_id: StringName, request_id: StringName) -> void:
	var circuit: Entity = entity_for(circuit_id)
	if circuit == null:
		return

	var event: LightFlickerRequest = LightFlickerRequest.new()
	event.kind = LightFlickerRequest.Kind.STOP
	event.request_id = request_id
	event.circuit_id = circuit_id
	ECS.world.emit_event(LightFlickerRequest.EVENT, circuit, event)

## Меняет цепь по постоянному авторскому ID.
static func set_by_id(circuit_id: StringName, enabled: bool) -> bool:
	return set_enabled(entity_for(circuit_id), enabled)

## Переключает enabled доступной сущности световой цепи.
static func toggle(circuit: Entity) -> bool:
	if not EntityAvailability.contains(circuit, ECS.world):
		return false

	var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
	return state != null and set_enabled(circuit, not state.enabled)

#endregion

#region Поиск цепи и кеш текущего мира
## Читает авторитетное состояние переключателя по постоянному ID.
static func is_enabled(circuit_id: StringName) -> bool:
	var state: C_LightCircuit = state_for(circuit_id)
	return state != null and state.enabled

## Читает текущие данные цепи через проверяемый кеш слабых ссылок сущностей.
static func state_for(circuit_id: StringName) -> C_LightCircuit:
	var circuit: Entity = entity_for(circuit_id)
	return circuit.get_component(C_LightCircuit) as C_LightCircuit if circuit != null else null

## Находит цепь через запрос текущего World; при смене мира кеш и QueryBuilder пересоздаются.
static func entity_for(circuit_id: StringName) -> Entity:
	if not is_instance_valid(ECS.world):
		return null
	if _lookup_world != ECS.world or not is_instance_valid(_lookup_world):
		_lookup_world = ECS.world
		_circuit_references.clear()
		_circuit_query = QueryBuilder.new(_lookup_world).with_all([C_LightCircuit])

	var reference: WeakRef = _circuit_references.get(circuit_id)
	var cached: Entity = reference.get_ref() as Entity if reference != null else null
	if cached != null and _lookup_world.entity_to_archetype.has(cached):
		var state: C_LightCircuit = cached.get_component(C_LightCircuit) as C_LightCircuit
		if state != null and state.circuit_id == circuit_id:
			return cached

	for circuit: Entity in _circuit_query.execute():
		var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
		_circuit_references[state.circuit_id] = weakref(circuit)
		if state.circuit_id == circuit_id:
			return circuit
	return null
#endregion
