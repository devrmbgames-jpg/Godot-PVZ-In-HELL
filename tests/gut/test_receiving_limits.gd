extends "res://tests/gut/test_district_service.gd"
## Проверяет лимиты реальной поставки и связь коробок с живыми получателями.

var _supply: DEF_Delivery = null

#region Fixture
## Использует настоящий ассортимент и дешёвые компоненты физических коробок.
func before_each() -> void:
	super.before_each()
	var flow: C_CustomerFlow = CustomerFlowService.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.events = (load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule).events
	_supply = flow.schedule.supply

func _waiting_package(index: int) -> CustomerVisit:
	var parcel_node: Node = Node.new()
	parcel_node.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var parcel: Entity = parcel_node as Entity
	var identity: C_Package = C_Package.new()
	identity.package_id = "limit/" + str(index)
	identity.definition = _supply.packages[0]
	parcel.component_resources = [identity, C_PackageState.new()]
	_world.add_entity(parcel)
	var visit: CustomerVisit = _case(_district.people[0], "limit/" + str(index))
	visit.package_id = identity.package_id
	return visit
#endregion

#region Supply policy
## Пять коробок за день; длинная фаза и повторная команда не создают новую партию.
func test_daily_batch_is_limited_rotates_and_does_not_accumulate() -> void:
	var receiving: C_Receiving = C_Receiving.new()
	ReceivingDeliveryService.prepare_batch(_supply, receiving, 1)
	assert_eq(receiving.pending.size(), 1)
	assert_eq(receiving.pending[0].package_keys.size(), 5)
	var first_keys: PackedStringArray = receiving.pending[0].package_keys.duplicate()
	ReceivingDeliveryService.prepare_batch(_supply, receiving, 1)
	assert_eq(receiving.pending.size(), 1)
	assert_eq(receiving.pending[0].package_keys, first_keys)
	ReceivingDeliveryService.prepare_batch(_supply, receiving, 2)
	assert_eq(receiving.pending.size(), 1)
	assert_eq(receiving.pending[0].day_index, 2)
	assert_ne(receiving.pending[0].package_keys, first_keys)
	var decoded: ReceivingBatch = SaveDataCodec.decode(SaveDataCodec.encode(receiving.pending[0])) as ReceivingBatch
	assert_eq(decoded.package_keys, receiving.pending[0].package_keys)

## Остаток лимита сокращает партию; пятьдесят ожидающих полностью останавливают поставку.
func test_waiting_capacity_limits_supply_without_new_backlog() -> void:
	for index: int in 49:
		_waiting_package(index)
	assert_eq(ReceivingDeliveryService.waiting_count(), 49)
	var receiving: C_Receiving = C_Receiving.new()
	ReceivingDeliveryService.prepare_batch(_supply, receiving, 1)
	assert_eq(receiving.pending[0].package_keys.size(), 1)
	_waiting_package(49)
	assert_eq(ReceivingDeliveryService.waiting_count(), 50)
	ReceivingDeliveryService.prepare_batch(_supply, receiving, 2)
	assert_eq(receiving.pending.size(), 0)
	assert_eq(receiving.last_started_day, 2)

## Потеря, отказ, выдача и окончательная смерть не занимают место ожидающего заказа.
func test_terminal_cases_and_dead_recipients_do_not_count() -> void:
	var lost: CustomerVisit = _waiting_package(0)
	lost.declaration = CustomerVisit.Declaration.LOST
	var refused: CustomerVisit = _waiting_package(1)
	refused.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
	var dead: CustomerVisit = _waiting_package(2)
	dead.customer_dead = true
	var delivered: CustomerVisit = _waiting_package(3)
	delivered.actual = CustomerVisit.Actual.DELIVERED
	var active: CustomerVisit = _waiting_package(4)
	assert_eq(ReceivingDeliveryService.waiting_count(), 1)
	active.customer_dead = true
	assert_eq(ReceivingDeliveryService.waiting_count(), 0)

## Каждая позиция авторского ассортимента имеет визит и живого получателя.
func test_every_supply_package_has_a_real_recipient_case() -> void:
	for definition: DEF_Package in _supply.packages:
		var identity: C_Package = C_Package.new()
		identity.definition = definition
		identity.supply_key = _supply.key
		identity.delivery_day = 1
		var visit: CustomerVisit = CustomerFlowService.plan_delivered_package(identity)
		assert_not_null(visit, String(definition.key))
		assert_not_null(DistrictPopulationService.person_for(visit.customer_id))
		assert_same(CustomerFlowService.plan_delivered_package(identity), visit)
	assert_eq(CustomerFlowService.current().visits.size(), _supply.packages.size())
#endregion
