extends RefCounted
## Читает принятые обязательства и живые встречи без обращения к потоку визитов.
class_name HomeMeetingQueries


#region Доступность встречи
## Принятое обещание доступно вечером до действительного срока, включая сообщение об отсутствии.
static func job_for_address(address_id: StringName) -> NpcHomeDelivery:
	var district: C_District = NpcPopulationQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if district == null or cycle == null or cycle.phase != C_DayCycle.Phase.EVENING:
		return null

	for job: NpcHomeDelivery in district.home_deliveries:
		var deadline: int = HomeDeliveryDeadlineRules.active_deadline_day(
			job,
			NpcPopulationQueries.person_for(job.npc_id),
		)
		if (
			job.address_id == address_id and job.day_index <= cycle.day_index
			and job.status == NpcHomeDelivery.Status.ACCEPTED
			and (deadline == 0 or deadline > cycle.day_index)
		):
			return job
	return null


## Возвращает обязательство только пока живая связь резервирует его дверь.
static func meeting_for(body: Entity) -> NpcHomeDelivery:
	if not is_instance_valid(body):
		return null

	for link: Relationship in body.relationships:
		if (
			link.relation is R_NpcHomeMeeting
			and EntityAvailability.contains(link.target, ECS.world)
		):
			for job: NpcHomeDelivery in NpcPopulationQueries.current().home_deliveries:
				if (
					job.job_id == (link.relation as R_NpcHomeMeeting).job_id
					and job.status == NpcHomeDelivery.Status.ACCEPTED
				):
					return job
	return null


## Возвращает живую дверь для возврата из осмотра к домашней встрече.
static func door_for(body: Entity) -> Entity:
	for link: Relationship in body.relationships:
		if (
			link.relation is R_NpcHomeMeeting
			and EntityAvailability.contains(link.target, ECS.world)
		):
			return link.target as Entity
	return null
#endregion
