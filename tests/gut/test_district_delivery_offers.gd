extends "res://tests/gut/test_district_delivery.gd"
## Реальные зарегистрированные заказы, устойчивый выбор источника и сохраняемые решения доставки.

#region Настройки fixture
## Оставляет выбор личного минимума и трёх терминальных заказов детерминированным.
func before_each() -> void:
	super.before_each()
	_district.definition.terminal_delivery_minimum = 3
	_district.definition.terminal_delivery_maximum = 3

func _pause_offers() -> void:
	_district.definition.terminal_delivery_minimum = 0
	_district.definition.terminal_delivery_maximum = 0
	_district.definition.personal_delivery_daily_minimum = 0

func _next_day() -> void:
	DayPhaseService.current().day_index += 1
	NpcDeliveryOfferService.refresh()

func _job(visit: CustomerVisit) -> NpcHomeDelivery:
	for job: NpcHomeDelivery in _district.home_deliveries:
		if job.visit_id == visit.visit_id:
			return job
	return null
#endregion

#region Пригодность и однократный выбор
## Четыре реальные регистрации создают личный минимум и три разных терминальных предложения.
func test_daily_choice_has_one_personal_and_three_terminal_orders() -> void:
	for index: int in [0, 3, 6, 1]:
		_delivery_case(_district.people[index], "offer_%d" % index)
	assert_eq(_district.home_deliveries.size(), 4)
	assert_eq(NpcDeliveryOfferService.terminal_offers().size(), 3)
	assert_eq(_district.delivery_considered.size(), 4)
	var ids: PackedStringArray = []
	for job: NpcHomeDelivery in _district.home_deliveries:
		assert_false(ids.has(String(job.job_id)))
		ids.append(String(job.job_id))
		assert_false(job.package_id.is_empty())
		assert_false(job.package_history_id.is_empty())
		assert_eq(job.status, NpcHomeDelivery.Status.OFFERED)
		assert_eq(job.deadline_day, 2)
		assert_eq(job.bonus, 10)
	for repetition: int in range(5):
		NpcDeliveryOfferService.refresh()
	assert_eq(_district.home_deliveries.size(), 4)
	assert_eq(String(_district.home_deliveries[0].job_id), ids[0])
	assert_false(_district.home_deliveries[0].published)
	assert_eq(WalletService.current().operations.size(), 0)

## При единственном кандидате личный минимум не создаёт вымышленные терминальные коробки.
func test_candidate_shortage_preserves_private_personal_minimum() -> void:
	_delivery_case(_district.people[0], "single")
	assert_eq(_district.home_deliveries.size(), 1)
	assert_eq(_district.home_deliveries[0].source, NpcHomeDelivery.Source.PERSONAL)
	assert_eq(NpcDeliveryOfferService.terminal_offers().size(), 0)
	assert_eq(_district.terminal_offer_target, 3)
	assert_eq(NpcHomeDeliveryService.status_text(), "")

## Приезжий, погибший, незарегистрированный и закрытый заказ не получают предложения.
func test_ineligible_orders_are_excluded_from_next_morning_choice() -> void:
	_pause_offers()
	_delivery_case(_district.people[8], "visitor")
	_delivery_case(_district.people[3], "dead")
	DistrictPopulationService.mark_dead(_district.people[3], DistrictPopulationService.body_for(_district.people[3].npc_id), 1)
	var lost: CustomerVisit = _delivery_case(_district.people[6], "lost")
	lost.declaration = CustomerVisit.Declaration.LOST
	var delivered: CustomerVisit = _delivery_case(_district.people[1], "delivered")
	delivered.actual = CustomerVisit.Actual.DELIVERED
	var disputed: CustomerVisit = _delivery_case(_district.people[2], "complaint")
	disputed.complaint = CustomerComplaint.new()
	_case(_district.people[4], "unregistered")
	var eligible: CustomerVisit = _delivery_case(_district.people[0], "eligible")
	_district.definition.terminal_delivery_minimum = 3
	_district.definition.terminal_delivery_maximum = 3
	_district.definition.personal_delivery_daily_minimum = 1
	_next_day()
	assert_eq(_district.home_deliveries.size(), 1)
	assert_eq(_district.home_deliveries[0].visit_id, eligible.visit_id)
	assert_eq(_district.delivery_considered.size(), 1)

## Изменение вероятности не перебрасывает уже рассмотренный заказ внутри дня.
func test_considered_order_waits_for_next_day_before_new_roll() -> void:
	_pause_offers()
	_delivery_case(_district.people[0], "considered")
	assert_eq(_district.home_deliveries.size(), 0)
	assert_eq(_district.delivery_considered.size(), 1)
	_district.definition.personal_delivery_probability = 1.0
	NpcDeliveryOfferService.refresh()
	assert_eq(_district.home_deliveries.size(), 0)
	_next_day()
	assert_eq(_district.home_deliveries.size(), 1)
	assert_eq(_district.home_deliveries[0].day_index, 2)

## Даже ошибочно продублированный визит не создаёт два предложения одной коробке.
func test_duplicate_visits_cannot_compete_for_one_package() -> void:
	_pause_offers()
	var first: CustomerVisit = _delivery_case(_district.people[0], "shared")
	var duplicate: CustomerVisit = _case(_district.people[0], "duplicate")
	duplicate.package_id = first.package_id
	_district.definition.personal_delivery_probability = 1.0
	_next_day()
	assert_eq(_district.home_deliveries.size(), 1)
	assert_eq(_district.home_deliveries[0].visit_id, first.visit_id)
#endregion

#region Решения и цена
## Принятие трёх предложений не имеет общего лимита; отказ терминалу не переносит клиента.
func test_accept_and_decline_are_idempotent_without_two_job_cap() -> void:
	_delivery_case(_district.people[0], "personal")
	var declined: CustomerVisit = _delivery_case(_district.people[3], "declined")
	_delivery_case(_district.people[6], "accepted_a")
	_delivery_case(_district.people[1], "accepted_b")
	var job: NpcHomeDelivery = _job(declined)
	assert_true(NpcDeliveryOfferService.decline(job.job_id))
	assert_true(NpcDeliveryOfferService.decline(job.job_id))
	assert_false(declined.home_delivery_declined)
	assert_false(declined.finished)
	assert_eq(declined.next_followup_day, 0)
	assert_false(NpcDeliveryOfferService.accept(job.job_id))
	var accepted: int = 0
	for candidate: NpcHomeDelivery in _district.home_deliveries:
		if candidate == job:
			continue
		assert_true(NpcDeliveryOfferService.accept(candidate.job_id))
		assert_true(NpcDeliveryOfferService.accept(candidate.job_id))
		accepted += 1
	assert_eq(accepted, 3)
	assert_eq(NpcDeliveryOfferService.terminal_offers().size(), 0)
	assert_eq(WalletService.current().balance, 0)

## Фиксированная цена терминала сохраняется при изменении базовой оплаты и настроек.
func test_terminal_price_is_captured_and_cannot_be_bargained() -> void:
	_district.definition.terminal_delivery_bonus = 27
	_delivery_case(_district.people[0], "minimum")
	var visit: CustomerVisit = _delivery_case(_district.people[3], "fixed")
	var job: NpcHomeDelivery = _job(visit)
	assert_eq(job.bonus, 27)
	visit.payment = 99
	_district.definition.terminal_delivery_bonus = 42
	NpcDeliveryOfferService.refresh()
	assert_eq(job.bonus, 27)
	assert_eq(NpcDeliveryOfferService.negotiate(job.job_id), NpcHomeDelivery.Bargain.NONE)

## Успешный торг применяется один раз и выплачивает сохранённую доплату.
func test_successful_bargain_has_one_increment_and_one_bonus_operation() -> void:
	_district.definition.delivery_bargain_probability = 1.0
	var visit: CustomerVisit = _delivery_case(_district.people[0], "bargain")
	var job: NpcHomeDelivery = _job(visit)
	assert_eq(NpcDeliveryOfferService.negotiate(job.job_id), NpcHomeDelivery.Bargain.ACCEPTED)
	assert_eq(job.bonus, 15)
	_district.definition.delivery_bargain_probability = 0.0
	assert_eq(NpcDeliveryOfferService.negotiate(job.job_id), NpcHomeDelivery.Bargain.ACCEPTED)
	assert_eq(job.bonus, 15)
	assert_true(NpcDeliveryOfferService.accept(job.job_id))
	var body: E_DistrictNpc = DistrictPopulationService.body_for(visit.customer_id)
	assert_true(NpcHomeDeliveryService.knock(_player, _door(job.address_id)))
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.READY)
	assert_true(NpcHomeDeliveryService.complete(job))
	assert_eq(WalletService.current().balance, 25)
	assert_true(NpcHomeDeliveryService.complete(job))
	assert_eq(WalletService.current().operations.size(), 2)

## Отказ в торге сохраняет исходную цену и не превращает повторный разговор в новый бросок.
func test_failed_bargain_still_allows_original_offer() -> void:
	_district.definition.delivery_bargain_probability = 0.0
	var visit: CustomerVisit = _delivery_case(_district.people[0], "no_bargain")
	var job: NpcHomeDelivery = _job(visit)
	assert_eq(NpcDeliveryOfferService.negotiate(job.job_id), NpcHomeDelivery.Bargain.DECLINED)
	_district.definition.delivery_bargain_probability = 1.0
	assert_eq(NpcDeliveryOfferService.negotiate(job.job_id), NpcHomeDelivery.Bargain.DECLINED)
	assert_eq(job.bonus, 10)
	assert_true(NpcDeliveryOfferService.accept(job.job_id))

## Авторское назначение переиспользует непринятое предложение, сохраняя один ID и частность.
func test_scripted_personal_offer_has_stable_identity_and_scenario() -> void:
	_delivery_case(_district.people[0], "minimum")
	var visit: CustomerVisit = _delivery_case(_district.people[3], "scripted")
	var previous: NpcHomeDelivery = _job(visit)
	var job: NpcHomeDelivery = NpcDeliveryOfferService.assign_personal(visit.visit_id, &"delivery_trap")
	assert_same(job, previous)
	assert_eq(job.source, NpcHomeDelivery.Source.PERSONAL)
	assert_false(job.published)
	assert_eq(job.scenario_id, &"delivery_trap")
	assert_same(NpcDeliveryOfferService.assign_personal(visit.visit_id, &"delivery_trap"), job)
	assert_null(NpcDeliveryOfferService.assign_personal(visit.visit_id, &"different"))
	assert_eq(_district.home_deliveries.size(), 2)

## Уничтоженная коробка не позволяет принять старое уведомление и не объявляется потерянной.
func test_stale_offer_cannot_accept_missing_box() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "missing")
	var job: NpcHomeDelivery = _job(visit)
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	_world.remove_entity(parcel)
	parcel.queue_free()
	assert_false(NpcDeliveryOfferService.accept(job.job_id))
	assert_eq(job.status, NpcHomeDelivery.Status.OFFERED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)

## Непринятые предложения истекают без неприязни; повтор сна не создаёт нового предложения.
func test_unaccepted_offers_expire_without_broken_promise() -> void:
	_delivery_case(_district.people[0], "expiry")
	NpcHomeDeliveryService.finish_evening(1)
	NpcHomeDeliveryService.finish_evening(1)
	assert_eq(_district.home_deliveries[0].status, NpcHomeDelivery.Status.EXPIRED)
	assert_eq(_district.people[0].memories.size(), 0)
	_next_day()
	assert_eq(_district.home_deliveries.size(), 1)
	assert_eq(WalletService.current().balance, 0)
#endregion

#region Постоянный снимок
## Codec восстанавливает выбор, частное предложение, цену и торг без временных Node-ссылок.
func test_offer_catalogue_round_trip_keeps_ids_decisions_and_selection() -> void:
	_district.definition.delivery_bargain_probability = 1.0
	var personal: CustomerVisit = _delivery_case(_district.people[0], "persist_personal")
	_delivery_case(_district.people[3], "persist_terminal")
	var job: NpcHomeDelivery = _job(personal)
	NpcDeliveryOfferService.negotiate(job.job_id)
	var roll: float = job.bargain_roll
	var job_id: StringName = job.job_id
	_district.definition = load("res://content/definitions/gameplay/npc/def_district_default.tres") as DEF_District
	var copy: C_District = C_District.new()
	var fields: Dictionary = SaveDataCodec.component_data(_district).fields as Dictionary
	assert_true(SaveDataCodec.apply_fields(copy, fields))
	assert_eq(copy.delivery_offer_day, 1)
	assert_eq(copy.terminal_offer_target, 3)
	assert_eq(copy.delivery_considered, _district.delivery_considered)
	assert_eq(copy.home_deliveries.size(), 2)
	assert_eq(copy.home_deliveries[0].job_id, job_id)
	assert_eq(copy.home_deliveries[0].bargain_roll, roll)
	assert_eq(copy.home_deliveries[0].bargain, NpcHomeDelivery.Bargain.ACCEPTED)
	assert_eq(copy.home_deliveries[0].bonus, 15)
	assert_false(copy.home_deliveries[0].published)
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.remove_component(C_District)
	session.add_component(copy)
	_district = session.get_component(C_District) as C_District
	NpcDeliveryOfferService.refresh()
	assert_eq(_district.home_deliveries.size(), 2)
	assert_eq(NpcDeliveryOfferService.negotiate(job_id), NpcHomeDelivery.Bargain.ACCEPTED)
	assert_eq(NpcDeliveryOfferService.find(job_id).bonus, 15)
#endregion
