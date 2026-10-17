extends "res://tests/smoke/npc_life_cycle_smoke.gd"
## Холодный запуск прежнего заказа: отсутствие, два возврата, та же коробка и доплата.

const ORDER_SAVE_PATH: String = "user://npc_return_orders_smoke.pvzh"
const VISIT_ID: StringName = &"smoke/return_order"
const PACKAGE_ID: String = "smoke/return_parcel"
const PHYSICAL_ID: String = "smoke/return_physical_parcel"


#region Настоящий поток и отдельный слот
func _save_path() -> String:
	return ORDER_SAVE_PATH


func _completion_prefix() -> String:
	return "NPC orders smoke"


func _create_world(world_seed: int) -> void:
	super._create_world(world_seed)
	CustomerFlowFixture.install()
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	flow.schedule = load(
		"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
	) as DEF_CustomerSchedule
	session.add_component(flow)
	session.add_component(C_Wallet.new())
	session.add_component(C_PackageLedger.new())


func _write() -> void:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = VISIT_ID
	visit.customer_id = _person_id()
	visit.package_id = PACKAGE_ID
	visit.payment = 17
	visit.requires_registered_package = false
	var schedule: DEF_CustomerSchedule = CustomerFlowQueries.current().schedule
	visit.definition = schedule.events[0].customer
	CustomerFlowQueries.current().visits.append(visit)
	var parcel: E_Package = (
		load("res://content/domains/packages/entities/package_a.tscn") as PackedScene
	).instantiate() as E_Package
	parcel.id = PHYSICAL_ID
	parcel.package_id = PACKAGE_ID
	parcel.package_definition = schedule.supply.packages[0]
	EntityCompositionFixture.register(_world, parcel)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	_check(
		PackageRegistrationService.register_package(parcel).outcome
		== PackageScanResult.Outcome.REGISTERED,
		"real parcel registered",
	)
	var job: NpcHomeDelivery = NpcDeliveryOfferService.assign_personal(VISIT_ID, &"", true)
	_check(job != null, "one existing home promise")
	if job == null:
		return
	_check(NpcDeliveryOfferService.accept(job.job_id), "promise accepted")
	super._write()
	_check(visit.absence_sequence == 1 and not visit.customer_dead, "temporary personal absence")
	_check(HomeDeliveryQueries.active_deadline_day(job) == 0, "deadline paused without guessed day")


func _restore() -> void:
	var cold: Dictionary = AutosaveStore.read(_save_path())
	_check(WorldSnapshotService.valid(cold, _root), "cold order data valid")
	_check(WorldSnapshotService.can_restore(cold, _root), "cold order prefab preflight")
	if _failed:
		return
	super._restore()
	if _failed:
		return
	var district: C_District = NpcPopulationQueries.current()
	_check(district.home_deliveries.size() == 1, "no new promise or quota slot")
	if district.home_deliveries.size() != 1:
		return
	var job: NpcHomeDelivery = district.home_deliveries[0]
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(VISIT_ID)
	var parcel: Entity = PackageQueries.find_live_package(PACKAGE_ID)
	_check(job.visit_id == VISIT_ID and job.package_id == PACKAGE_ID, "same order and recipient")
	_check(job.day_index == 1 and job.deadline_day == 2, "original promise history retained")
	_check(
		HomeDeliveryQueries.active_deadline_day(job) == 6,
		"deadline follows second actual return",
	)
	_check(job.bonus == 17 and not job.bonus_committed, "same unpaid bonus")
	_check(job.status == NpcHomeDelivery.Status.ACCEPTED, "absence did not fail the promise")
	_check(visit.absence_sequence == 0 and visit.next_followup_day == 6, "same visit resumed")
	_check(
		visit.actual == CustomerVisit.Actual.NOT_RESOLVED
		and visit.declaration == CustomerVisit.Declaration.NONE,
		"financial truth unchanged",
	)
	_check(visit.followup_count == 0 and visit.visit_count == 0, "no imagined appearances")
	_check(parcel != null and parcel.id == PHYSICAL_ID, "same physical package identity")
	_check(WalletService.current().operations.is_empty(), "no phantom payout")
#endregion
