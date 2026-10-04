extends RefCounted
## Общий вход типизированного запроса; арифметикой здоровья владеет O_Damage.
class_name DamageRequestService


## Публикует отдельный снимок запроса к конкретной цели; null не становится broadcast.
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
	if request.operation == DamageRequest.Operation.DAMAGE:
		snapshot.combat_context = request.combat_context.duplicate(true) as CombatContext if request.combat_context != null else CombatAttribution.describe(snapshot)
	ECS.world.emit_event(DamageRequest.EVENT, snapshot.target, snapshot)
	return true

## Дополнительный построитель использует ту же границу отправки запроса.


## Создаёт одноразовый построитель запроса; отправка использует обычный submit.
static func create_request() -> DamageRequestBuilder:
	return DamageRequestBuilder.new()


## Одноразовая последовательная сборка запроса без изменения здоровья.
class DamageRequestBuilder:
	## Ещё не отправленный запрос; submit освобождает ссылку.
	var request := DamageRequest.new()


	## Задаёт вызвавшего действие участника и возвращает построитель.
	func with_instigator(e: Entity) -> DamageRequestBuilder:
		request.instigator = e
		return self


	## Задаёт фактический повреждающий источник и возвращает построитель.
	func with_source(e: Entity) -> DamageRequestBuilder:
		request.source = e
		return self


	## Задаёт конкретного получателя запроса.
	func with_target(e: Entity) -> DamageRequestBuilder:
		request.target = e
		return self


	## Задаёт сумму до сопротивления; допустимость проверяется общим контуром.
	func with_amount(v: float) -> DamageRequestBuilder:
		request.amount = v
		return self


	## Выбирает урон или лечение.
	func with_operation(o: DamageRequest.Operation) -> DamageRequestBuilder:
		request.operation = o
		return self


	## Задаёт тип урона для сопротивления и обратной связи.
	func with_damage_type(d: DamageRequest.Type) -> DamageRequestBuilder:
		request.damage_type = d
		return self


	## Отправляет через общую проверку и снимок, затем освобождает запрос; построитель одноразовый.
	func submit() -> bool:
		var submitted: bool = DamageRequestService.submit(request)
		request = null
		return submitted
