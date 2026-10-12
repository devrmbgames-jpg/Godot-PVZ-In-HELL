extends RefCounted
## Общий интерфейс UI; уличный и клиентский контексты обращаются к своим сервисам.
class_name NpcDialogueContext

var _delivery_job_id: StringName = &""
var _closed: bool = false
var _soul_confirmation_key: StringName = &""
var _soul_result: SoulTradeResult = null
var _blood_confirmation_key: StringName = &""
var _blood_result: BloodConsentResult = null


#region Интерфейс контекста
func _init(_actor: Entity = null, _interlocutor: Entity = null) -> void:
	pass


## Начинает конкретное взаимодействие после проверки условий.
func begin() -> bool:
	return false


## Освобождает участников, не владея модальным захватом ввода.
func end() -> void:
	invalidate()


## Seals a session during tree teardown without returning participants to gameplay.
func invalidate() -> void:
	_closed = true


## Проверяет текущих участников и условия предметной области.
func is_valid() -> bool:
	return false


## Проверяет возможность продолжения диалогового UI.
func can_continue() -> bool:
	return false


## Сохраняет авторский текст, пока конкретный адаптер не изменяет восприятие игрока.
func perceived_text(actual_text: String) -> String:
	return actual_text


## Shared variants select the existing role-specific flow through this read-only adapter.
func is_customer_service() -> bool:
	return false


## Adapts the current trait warning for both roles without advancing exposure or changing memory.
func gaze_warning_given() -> bool:
	return is_valid() and NpcDialogueService.gaze_warning_given(_delivery_npc())


## Reads perceived darkness without sampling light or changing combat, memory or trait clocks.
func player_in_hunting_darkness() -> bool:
	return is_valid() and NpcDarknessQueries.player_in_hunting_darkness(_delivery_npc())


## Written communication reads an authored cue; both role adapters retain their gameplay owners.
func uses_signboard() -> bool:
	return is_valid() and NpcDialogueService.uses_signboard(_delivery_npc())


## Shares the existing persistent personal memory view between street and service roles.
func holds_grudge() -> bool:
	return is_valid() and NpcDialogueService.has_grudge_against(_delivery_npc(), _delivery_player())


## Both roles read personal strength memory without changing social or combat state.
func respects_player() -> bool:
	return is_valid() and NpcDialogueService.has_respect_for(_delivery_npc(), _delivery_player())


## Both roles read durable actor-specific notice without sampling gaze or creating recognition.
func stalking_noticed() -> bool:
	return (
		is_valid() and NpcDialogueService.has_stalking_notice(_delivery_npc(), _delivery_player())
	)


## Применяет смысл ответа через конкретный игровой адаптер.
func apply_response_tags(_tags: PackedStringArray) -> bool:
	return false


## Проверяет, относится ли открытый UI к этому NPC, без создания новой живой связи.
func speaks_with(_npc: Entity) -> bool:
	return false
#endregion


#region Explicit soul confirmation adapter
## Observes the current offer/deadline; one context never allocates a second confirmation.
func can_offer_soul() -> bool:
	if not is_valid():
		return false
	if not _soul_confirmation_key.is_empty():
		var record: SoulTradeRecord = _soul_receipt()
		if record == null or record.outcome != SoulTradeRecord.Outcome.OFFERED:
			return false
	return SoulTradeService.available(_delivery_player(), _delivery_npc())


## Captures one durable offer only at an authored mutation cue; reopening retains its saved key.
func request_soul_offer() -> bool:
	if not can_offer_soul():
		return false
	if not _soul_confirmation_key.is_empty():
		return true
	var record: SoulTradeRecord = SoulTradeService.offer(_delivery_player(), _delivery_npc())
	if record == null:
		return false
	_soul_confirmation_key = record.confirmation_key
	return true


## Presents only a still-valid unresolved offer, without changing its captured terms.
func has_soul_offer() -> bool:
	var record: SoulTradeRecord = _soul_receipt()
	return (
		is_valid() and record != null and record.outcome == SoulTradeRecord.Outcome.OFFERED
		and SoulTradeService.available(_delivery_player(), _delivery_npc())
	)


## Requests acceptance through the authoritative ledger and permanent stat transaction.
func accept_soul_offer() -> bool:
	return _resolve_soul_offer(true)


## Requests refusal of this exact offer; previously accepted deals remain counted.
func decline_soul_offer() -> bool:
	return _resolve_soul_offer(false)


## Reads the actual committed result, including an idempotent replay.
func soul_offer_accepted() -> bool:
	return _soul_result != null and _soul_result.reason == &"accepted"


## Reads an actual committed refusal; accepting a key cannot be undone by a later refusal.
func soul_offer_declined() -> bool:
	return _soul_result != null and _soul_result.reason == &"declined"


## Reads the immutable captured Strength gain for the displayed confirmation.
func soul_strength_gain() -> float:
	var record: SoulTradeRecord = _soul_receipt()
	return record.strength_gain if record != null else 0.0


## Reads the immutable maximum-Health cost; it is never damage guessed by dialogue.
func soul_health_cost() -> float:
	var record: SoulTradeRecord = _soul_receipt()
	return record.maximum_health_cost if record != null else 0.0


## Reads the authored captured total acceptance threshold for forfeiting life.
func soul_fatal_count() -> int:
	var record: SoulTradeRecord = _soul_receipt()
	return record.fatal_deal_count if record != null else 0


## Reads the current authoritative total before confirmation without creating an offer.
func soul_accepted_count() -> int:
	if not is_valid():
		if _soul_result != null and _soul_result.receipt != null:
			return _soul_result.receipt.accepted_count
		return 0
	var ledger: C_SoulTrade = _delivery_player().get_component(C_SoulTrade) as C_SoulTrade
	return ledger.accepted_count if ledger != null else 0


func _resolve_soul_offer(accept: bool) -> bool:
	if not is_valid() or _soul_confirmation_key.is_empty():
		return false
	var request: SoulTradeRequest = SoulTradeRequest.new()
	request.actor = _delivery_player()
	request.dealer = _delivery_npc()
	request.confirmation_key = _soul_confirmation_key
	request.accept = accept
	_soul_result = SoulTradeService.submit(request)
	return _soul_result.reason == (&"accepted" if accept else &"declined")


func _soul_receipt() -> SoulTradeRecord:
	if _soul_result != null and _soul_result.receipt != null:
		return _soul_result.receipt
	var actor: Entity = _delivery_player()
	if _soul_confirmation_key.is_empty() or not EntityAvailability.contains(actor, ECS.world):
		return null
	return SoulTradeService.receipt_for(actor, _soul_confirmation_key)
#endregion


#region Explicit blood confirmation adapter
## Observes eligibility without allocating offers; a context retains one displayed confirmation.
func can_offer_blood() -> bool:
	if not is_valid():
		return false
	if not _blood_confirmation_key.is_empty():
		var record: BloodConsentRecord = _blood_receipt()
		if record == null or record.outcome != BloodConsentRecord.Outcome.OFFERED:
			return false
	return BloodConsentService.available(_delivery_player(), _delivery_npc())


## Captures terms only at an authored cue; reopening retains the durable pending key.
func request_blood_offer() -> bool:
	if not can_offer_blood():
		return false
	if not _blood_confirmation_key.is_empty():
		return true
	var record: BloodConsentRecord = BloodConsentService.offer(_delivery_player(), _delivery_npc())
	if record == null:
		return false
	_blood_confirmation_key = record.confirmation_key
	return true


## Presents a currently eligible unresolved offer without changing its captured percentage.
func has_blood_offer() -> bool:
	var record: BloodConsentRecord = _blood_receipt()
	return (
		is_valid() and record != null and record.outcome == BloodConsentRecord.Outcome.OFFERED
		and BloodConsentService.available(_delivery_player(), _delivery_npc())
	)


## Requests the common Health transaction for this exact displayed offer.
func accept_blood_offer() -> bool:
	return _resolve_blood_offer(true)


## Records refusal through its owner without creating damage or reversing a prior acceptance.
func decline_blood_offer() -> bool:
	return _resolve_blood_offer(false)


## Reads the actual committed result, including terminal replay.
func blood_offer_accepted() -> bool:
	return _blood_result != null and _blood_result.reason == &"accepted"


func blood_offer_declined() -> bool:
	return _blood_result != null and _blood_result.reason == &"declined"


## Reads the captured percentage; the gameplay owner samples current HP when accepted.
func blood_percent() -> int:
	var record: BloodConsentRecord = _blood_receipt()
	return record.percent if record != null else 0


func _resolve_blood_offer(accept: bool) -> bool:
	if not is_valid() or _blood_confirmation_key.is_empty():
		return false
	var request: BloodConsentRequest = BloodConsentRequest.new()
	request.actor = _delivery_player()
	request.dealer = _delivery_npc()
	request.confirmation_key = _blood_confirmation_key
	request.accept = accept
	_blood_result = BloodConsentService.submit(request)
	return _blood_result.reason == (&"accepted" if accept else &"declined")


func _blood_receipt() -> BloodConsentRecord:
	if _blood_result != null and _blood_result.receipt != null:
		return _blood_result.receipt
	var dealer: E_DistrictNpc = _delivery_npc()
	if _blood_confirmation_key.is_empty() or not EntityAvailability.contains(dealer, ECS.world):
		return null
	return BloodConsentService.receipt_for(dealer, _blood_confirmation_key)
#endregion


#region Личное предложение и торг
## Конкретный адаптер проверяет пригодность личного заказа.
func can_offer_delivery() -> bool:
	return false


## Читает сохранённый адрес, не публикуя его системе терминала.
func delivery_address() -> String:
	var job: NpcHomeDelivery = _delivery_record()
	return NpcPopulationQueries.place_name(job.address_id) if job != null else ""


## Читает текущую согласованную доплату.
func delivery_bonus() -> int:
	var job: NpcHomeDelivery = _delivery_record()
	return job.bonus if job != null else 0


## Читает сумму однократного запроса торга, по умолчанию +50%.
func requested_delivery_bonus() -> int:
	var job: NpcHomeDelivery = _delivery_record()
	var district: C_District = NpcPopulationQueries.current()
	if job == null or district == null:
		return 0

	var requested_bonus: float = (
		float(job.base_bonus) * district.definition.delivery_bargain_percent
	)
	return floori(requested_bonus / NpcDeliveryOfferService.PERCENT_SCALE)


## Вариант торга исчезает после сохранённого ответа NPC.
func can_bargain_delivery() -> bool:
	var job: NpcHomeDelivery = _delivery_record()
	return can_offer_delivery() and job != null and job.bargain == NpcHomeDelivery.Bargain.NONE


## Запрашивает один сохранённый ответ на повышение доплаты.
func negotiate_home_delivery() -> bool:
	var job: NpcHomeDelivery = _delivery_record()
	return (
		is_valid() and job != null
		and NpcDeliveryOfferService.negotiate(job.job_id) != NpcHomeDelivery.Bargain.NONE
	)


## Позволяет авторской ветке показать согласие или отказ без повторного броска.
func delivery_bargain_accepted() -> bool:
	var job: NpcHomeDelivery = _delivery_record()
	return job != null and job.bargain == NpcHomeDelivery.Bargain.ACCEPTED


## Передаёт только авторское предупреждение, а не скрытый итог сценария.
func delivery_hint() -> String:
	var scenario: DEF_NpcDeliveryScenario = (
		NpcDeliveryScenarioService.definition_for(_delivery_record())
	)
	return scenario.offer_hint if scenario != null else ""


## Выделяет личное незавершённое последствие предыдущего обещания.
func has_broken_promise() -> bool:
	return CustomerSocialService.pending_promise(_delivery_npc()) != null


## Применяет зафиксированную реакцию характера через сервис при следующем разговоре.
func resolve_broken_promise() -> bool:
	return is_valid() and CustomerSocialService.resolve_promise(_delivery_npc(), _delivery_player())


func _delivery_record() -> NpcHomeDelivery:
	if not _delivery_job_id.is_empty():
		return HomeDeliveryQueries.find(_delivery_job_id)

	var job: NpcHomeDelivery = _delivery_offer()
	if job != null:
		_delivery_job_id = job.job_id
	return job


func _delivery_offer() -> NpcHomeDelivery:
	return null


func _delivery_npc() -> E_DistrictNpc:
	return null


func _delivery_player() -> Entity:
	return null
#endregion
