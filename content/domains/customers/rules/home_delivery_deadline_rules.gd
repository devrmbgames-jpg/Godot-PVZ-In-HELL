extends RefCounted
## Личный срок доставки по неизменному обещанию и фактической истории отсутствия получателя.
class_name HomeDeliveryDeadlineRules


#region Личный срок
## Срок принятого обещания вычисляется по фактическим возвращениям, не по ожидаемому +2.
## Ноль — личный срок приостановлен. Уже пропущенный срок и закрытые исходы не прощаются.
static func active_deadline_day(job: NpcHomeDelivery, person: NpcRecord) -> int:
	var deadline: int = job.deadline_day
	if job.status != NpcHomeDelivery.Status.ACCEPTED:
		return deadline
	if person == null:
		return deadline
	for episode: NpcDeathRecord in person.deaths:
		if episode.day < job.day_index:
			continue
		if episode.day >= deadline:
			break
		if episode.returned_day == 0:
			return 0
		deadline = maxi(deadline, episode.returned_day + 1)
	return deadline

#endregion
