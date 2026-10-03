extends GameDefinition
## Phase anchors and weekly presence; phase duration never advances the calendar.
class_name DEF_NpcSchedule

enum Location { STREET, HOME, OUTSIDE }

## Weekdays on which this person may enter the district, Monday = 0.
@export var weekdays: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4, 5, 6])
## Morning placement after the sleep boundary.
@export var morning: Location = Location.STREET
## Daytime work or activity placement.
@export var day: Location = Location.OUTSIDE
## Evening placement after work.
@export var evening: Location = Location.STREET

#region Schedule queries
## Returns the authored location for this day and phase.
func location_for(day_index: int, phase: C_DayCycle.Phase) -> Location:
	if not weekdays.has((day_index - 1) % 7):
		return Location.OUTSIDE
	match phase:
		C_DayCycle.Phase.MORNING: return morning
		C_DayCycle.Phase.DAY: return day
		C_DayCycle.Phase.EVENING: return evening
	return Location.HOME
#endregion
