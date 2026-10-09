@tool
extends GameDefinition
## Reusable authored Smart Object schema; live occupancy belongs only to Relationships.
class_name DEF_SmartObject

## Native local marker positions with unique stable slot IDs.
@export var slots: Array[DEF_SmartSlot] = []
## Operations and eligibility; variations reuse existing typed executors.
@export var affordances: Array[DEF_SmartAffordance] = []


#region Immutable lookups
## Resolves an authored operation without consulting runtime state.
func affordance_for(affordance_id: StringName) -> DEF_SmartAffordance:
	for affordance: DEF_SmartAffordance in affordances:
		if affordance != null and affordance.affordance_id == affordance_id:
			return affordance
	return null


## Resolves the stable service slot independently of an instantiated marker.
func slot_for(slot_id: StringName) -> DEF_SmartSlot:
	for service_slot: DEF_SmartSlot in slots:
		if service_slot != null and service_slot.slot_id == slot_id:
			return service_slot
	return null
#endregion
