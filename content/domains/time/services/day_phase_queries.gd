extends RefCounted
## Читает установленный цикл дня без запроса или исполнения перехода.
class_name DayPhaseQueries

#region Чтение состояния
## Возвращает данные цикла текущей сессии или null.
static func current() -> C_DayCycle:
	if not is_instance_valid(ECS.world):
		return null

	var session: Entity = ECS.world.query.with_all([C_DayCycle]).execute_one()
	return session.get_component(C_DayCycle) as C_DayCycle if session != null else null
#endregion
