extends RefCounted
## Общий интерфейс UI; уличный и клиентский контексты обращаются к своим сервисам.
class_name NpcDialogueContext

## Локальный кеш первого job ID; сам заказ каждый раз читается у HomeDeliveryQueries.
var _delivery_job_id: StringName = &""
var _closed: bool = false
var _return_sequence: int = 0
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


## Закрывает контекст при удалении дерева, не возвращая участников к игровым действиям.
func invalidate() -> void:
	_closed = true


## Проверяет текущих участников и условия предметной области.
func is_valid() -> bool:
	return false


## Проверяет возможность продолжения диалогового UI.
func can_continue() -> bool:
	return false


## Читает актуальное имя постоянной личности; закрытый контекст или отсутствие личности дают "".
## Конкретный адаптер обычного клиента предоставляет имя из его авторских данных.
func speaker_name() -> String:
	if not is_valid():
		return ""
	var person: NpcRecord = NpcPopulationQueries.person_for(
		NpcSocialService.identity_for(_delivery_npc()),
	)
	return person.display_name if person != null else ""


## Сохраняет авторский текст, пока конкретный адаптер не изменяет восприятие игрока.
func perceived_text(actual_text: String) -> String:
	return actual_text


## Возвращает true для обслуживания заказа; общие диалоги выбирают ветку без изменения роли.
func is_customer_service() -> bool:
	return false


## Читает уже выданное предупреждение о взгляде; не продвигает таймер и не меняет память.
## Для невалидного контекста возвращает false.
func gaze_warning_given() -> bool:
	return is_valid() and NpcDialogueService.gaze_warning_given(_delivery_npc())


## Читает воспринятую темноту игрока без нового замера света и изменения боя или таймеров.
## Для невалидного контекста возвращает false.
func player_in_hunting_darkness() -> bool:
	return is_valid() and NpcDarknessQueries.player_in_hunting_darkness(_delivery_npc())


## Проверяет авторский режим общения через табличку, не меняя состояние собеседника.
## Для невалидного контекста возвращает false.
func uses_signboard() -> bool:
	return is_valid() and NpcDialogueService.uses_signboard(_delivery_npc())


## Проверяет, помнит ли этот НПЦ с чертой злопамятности личную обиду на текущего игрока.
## Читает сохранённые инциденты; отношение и бой не изменяет.
## Учитывает личные угрозы, ложь, нарушенное обещание, нападение и другие обиды по
## NpcGrudgeRules; увиденный вред другому НПЦ сам по себе личной обидой не считается.
## Невалидный контекст или отсутствие подходящей памяти дают false.
func holds_grudge() -> bool:
	return is_valid() and NpcDialogueService.has_grudge_against(_delivery_npc(), _delivery_player())


## Проверяет сохранённое уважение к силе игрока без изменения отношений или боя.
## Для невалидного контекста возвращает false.
func respects_player() -> bool:
	return is_valid() and NpcDialogueService.has_respect_for(_delivery_npc(), _delivery_player())


## Читает личную память о замеченной слежке; не замеряет взгляд и не создаёт узнавание.
## Для невалидного контекста возвращает false.
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



#region Первый уместный разговор после возвращения
## Читает первый нерассказанный личный эпизод, не изменяя историю.
func has_return_response() -> bool:
	var person: NpcRecord = _dialogue_person()
	return person != null and NpcLifeRules.pending_response(person) != null


## Панель вызывает после показа строки с тегом; отменённое async чтение показом не считается.
func note_line_presented(tags: PackedStringArray) -> void:
	if tags.has("return_memory") and is_valid() and _return_sequence > 0:
		NpcSocialService.note_return_response(_delivery_npc(), _return_sequence)


## Читает только знание личности; фактический скрытый источник не становится обвинением.
func return_blame() -> String:
	var episode: NpcDeathRecord = _return_episode()
	if episode == null:
		return "unknown"
	if episode.known_actor_id == &"player":
		return "player"
	if not episode.known_actor_id.is_empty():
		return "npc"
	if episode.suspected_actor_id == &"player":
		return "suspected_player"
	return "suspected_npc" if not episode.suspected_actor_id.is_empty() else "unknown"


## Читает имя уже распознанного лица; неизвестный урон не раскрывает скрытую личность.
func return_actor_name() -> String:
	var episode: NpcDeathRecord = _return_episode()
	if episode == null:
		return ""
	var known_id: StringName = (
		episode.known_actor_id
		if not episode.known_actor_id.is_empty() else episode.suspected_actor_id
	)
	var other: NpcRecord = NpcPopulationQueries.person_for(known_id)
	return other.display_name if other != null else ""


## Выражение реакции выбирает существующий авторский характер; новый тип не назначается.
func return_style() -> String:
	var person: NpcRecord = _dialogue_person()
	if person == null:
		return ""
	match person.profile.personality:
		DEF_NpcProfile.Personality.TIMID:
			return "timid"
		DEF_NpcProfile.Personality.AGGRESSIVE:
			return "aggressive"
		DEF_NpcProfile.Personality.BRAZEN:
			return "brazen"
	return "cheerful"


func _return_episode() -> NpcDeathRecord:
	var person: NpcRecord = _dialogue_person()
	if person == null:
		return null
	if _return_sequence == 0:
		var pending: NpcDeathRecord = NpcLifeRules.pending_response(person)
		if pending != null:
			_return_sequence = pending.sequence
	return NpcLifeRules.episode_for(person, _return_sequence)
#endregion


#region Авторская память постоянной личности
## Устанавливает флаг в true; повтор безопасен, закрытый ctx не выполняет запись.
func set_tag(tag_name: StringName) -> void:
	var person: NpcRecord = _dialogue_person()
	if person != null:
		NpcDialogueMemoryService.set_tag(person, tag_name)


## Отсутствующий флаг даёт false без создания ключа или личности.
func get_tag(tag_name: StringName) -> bool:
	var person: NpcRecord = _dialogue_person()
	return person != null and NpcDialogueMemoryService.get_tag(person, tag_name)


## Сохраняет исходный Variant, включая явный null; закрытый ctx не выполняет запись.
## Непредставимые на диске runtime-значения отклоняет preflight сохранения.
func set_val(value_name: StringName, value: Variant) -> void:
	var person: NpcRecord = _dialogue_person()
	if person != null:
		NpcDialogueMemoryService.set_val(person, value_name, value)


## Читает сохранённый тип; отсутствие ключа даёт null без записи.
func get_val(value_name: StringName) -> Variant:
	var person: NpcRecord = _dialogue_person()
	return NpcDialogueMemoryService.get_val(person, value_name) if person != null else null


## Складывает только int/float; отсутствие начинает с нуля, int + int остаётся int.
## bool, null и другие нечисловые значения дают диагностику без изменения памяти.
## Каждый новый авторский вызов прибавляет снова; закрытый ctx не выполняет запись.
func add_val(value_name: StringName, value: Variant) -> void:
	var person: NpcRecord = _dialogue_person()
	if person == null:
		return
	var diagnostic: String = NpcDialogueMemoryService.add_val(person, value_name, value)
	if not diagnostic.is_empty():
		push_warning(diagnostic)


func _dialogue_person() -> NpcRecord:
	if _closed or not is_valid():
		return null
	return NpcPopulationQueries.person_for(NpcSocialService.identity_for(_delivery_npc()))
#endregion


#region Явное подтверждение сделки с душой
## Проверяет доступность сделки и срок предложения без создания подтверждения.
## Закрытый контекст или уже разрешённое предложение дают false.
func can_offer_soul() -> bool:
	if not is_valid():
		return false
	if not _soul_confirmation_key.is_empty():
		var record: SoulTradeRecord = _soul_receipt()
		if record == null or record.outcome != SoulTradeRecord.Outcome.OFFERED:
			return false
	return SoulTradeService.available(_delivery_player(), _delivery_npc())


## Запрашивает одно сохраняемое предложение в авторском шаге действия.
## Повтор использует сохранённый ключ; при недоступной сделке возвращает false.
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


## Возвращает true только для доступного неразрешённого предложения; условия не меняет.
func has_soul_offer() -> bool:
	var record: SoulTradeRecord = _soul_receipt()
	return (
		is_valid() and record != null and record.outcome == SoulTradeRecord.Outcome.OFFERED
		and SoulTradeService.available(_delivery_player(), _delivery_npc())
	)


## Запрашивает принятие через владельца реестра и постоянных характеристик.
## Возвращает true при подтверждённом принятии, включая повтор того же подтверждения.
func accept_soul_offer() -> bool:
	return _resolve_soul_offer(true)


## Запрашивает отказ от показанного предложения; ранее принятые сделки остаются учтены.
## Возвращает true при подтверждённом отказе.
func decline_soul_offer() -> bool:
	return _resolve_soul_offer(false)


## Проверяет фактически подтверждённое принятие, включая безопасный повтор.
func soul_offer_accepted() -> bool:
	return _soul_result != null and _soul_result.reason == &"accepted"


## Проверяет подтверждённый отказ; поздний отказ не отменяет принятие того же ключа.
func soul_offer_declined() -> bool:
	return _soul_result != null and _soul_result.reason == &"declined"


## Читает зафиксированный прирост силы показанного предложения; без него возвращает 0.
func soul_strength_gain() -> float:
	var record: SoulTradeRecord = _soul_receipt()
	return record.strength_gain if record != null else 0.0


## Читает зафиксированную цену максимального здоровья; без предложения возвращает 0.
## Сам диалог не рассчитывает и не применяет урон.
func soul_health_cost() -> float:
	var record: SoulTradeRecord = _soul_receipt()
	return record.maximum_health_cost if record != null else 0.0


## Читает зафиксированный порог числа сделок для потери жизни; без предложения даёт 0.
func soul_fatal_count() -> int:
	var record: SoulTradeRecord = _soul_receipt()
	return record.fatal_deal_count if record != null else 0


## Читает число принятых сделок из реестра без создания предложения.
## После закрытия доступно число из полученной квитанции; без неё возвращает 0.
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


#region Явное подтверждение передачи крови
## Проверяет доступность передачи крови без создания предложения.
## Закрытый контекст или уже разрешённое предложение дают false.
func can_offer_blood() -> bool:
	if not is_valid():
		return false
	if not _blood_confirmation_key.is_empty():
		var record: BloodConsentRecord = _blood_receipt()
		if record == null or record.outcome != BloodConsentRecord.Outcome.OFFERED:
			return false
	return BloodConsentService.available(_delivery_player(), _delivery_npc())


## Запрашивает сохраняемое предложение в авторском шаге действия.
## Повтор использует прежний ключ; при недоступном предложении возвращает false.
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


## Проверяет доступное неразрешённое предложение, не меняя зафиксированный процент.
func has_blood_offer() -> bool:
	var record: BloodConsentRecord = _blood_receipt()
	return (
		is_valid() and record != null and record.outcome == BloodConsentRecord.Outcome.OFFERED
		and BloodConsentService.available(_delivery_player(), _delivery_npc())
	)


## Запрашивает общую операцию здоровья для показанного подтверждения.
## Возвращает true при подтверждённом принятии, включая повтор того же ключа.
func accept_blood_offer() -> bool:
	return _resolve_blood_offer(true)


## Запрашивает отказ через владельца предложения, не создавая урон и не отменяя принятие.
## Возвращает true при подтверждённом отказе.
func decline_blood_offer() -> bool:
	return _resolve_blood_offer(false)


## Проверяет фактически подтверждённое принятие, включая повтор завершённой операции.
func blood_offer_accepted() -> bool:
	return _blood_result != null and _blood_result.reason == &"accepted"


## Проверяет подтверждённый отказ; без результата возвращает false.
func blood_offer_declined() -> bool:
	return _blood_result != null and _blood_result.reason == &"declined"


## Читает зафиксированный процент предложения; без него возвращает 0.
## Текущее здоровье измеряет владелец игровой операции в момент принятия.
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
