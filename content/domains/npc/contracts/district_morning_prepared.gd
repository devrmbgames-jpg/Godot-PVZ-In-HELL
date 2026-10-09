extends RefCounted
## Committed native morning preparation; higher owners prepare their own dependent state.
class_name DistrictMorningPrepared

## Native preparation outcome channel, distinct from advancing the calendar.
const EVENT: StringName = &"district_morning_prepared"
## Exact native aggregate witness, rejecting replacement across delivery.
var district: C_District
## Exact calendar witness at preparation; the future day does not advance it.
var cycle: C_DayCycle
## Future day successfully prepared by the native owner.
var day_index: int
## Calendar context captured at publication.
var context_day: int
## Calendar phase captured at publication.
var context_phase: C_DayCycle.Phase

#region Committed fact construction
## Captures native owner identities and the unchanged calendar context.
func _init(prepared_district: C_District, captured_cycle: C_DayCycle, prepared_day: int) -> void:
	district = prepared_district
	cycle = captured_cycle
	day_index = prepared_day
	context_day = captured_cycle.day_index
	context_phase = captured_cycle.phase
#endregion
