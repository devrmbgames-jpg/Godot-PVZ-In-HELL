extends GameDefinition
## Размещение по фазам и дням недели; длительность фазы не двигает календарь.
class_name DEF_NpcSchedule

enum Location { STREET, HOME, OUTSIDE }

## Дни недели появления в районе; понедельник имеет номер 0.
@export var weekdays: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4, 5, 6])
## Утреннее размещение после сна.
@export var morning: Location = Location.STREET
## Размещение на время дневной работы или занятия.
@export var day: Location = Location.OUTSIDE
## Вечернее размещение после работы.
@export var evening: Location = Location.STREET

#region Schedule queries
## Возвращает авторское размещение для заданного дня и фазы.
func location_for(day_index: int, phase: C_DayCycle.Phase) -> Location:
	if not weekdays.has((day_index - 1) % 7):
		return Location.OUTSIDE

	match phase:
		C_DayCycle.Phase.MORNING: return morning
		C_DayCycle.Phase.DAY: return day
		C_DayCycle.Phase.EVENING: return evening
	return Location.HOME
#endregion
