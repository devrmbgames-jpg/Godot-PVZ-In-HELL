extends RefCounted
## Pure authored schema checks shared by compiler, Inspector preview and headless diagnostics.
class_name SmartObjectRules


#region Authored contract validation
## Rejects absent/ambiguous slots, markers and executors before materialization.
static func issues(definition: DEF_SmartObject, actor: Node) -> PackedStringArray:
	var messages: PackedStringArray = PackedStringArray()
	if definition == null:
		return PackedStringArray(["Smart Object requires a definition"])
	var slot_ids: Dictionary[StringName, bool] = { }
	for service_slot: DEF_SmartSlot in definition.slots:
		if service_slot == null or service_slot.slot_id.is_empty():
			messages.append("Smart Object slot requires a stable ID")
			continue
		if slot_ids.has(service_slot.slot_id):
			messages.append("Duplicate Smart Object slot: %s" % service_slot.slot_id)
		slot_ids[service_slot.slot_id] = true
		if (
			service_slot.marker.is_empty()
			or not actor.get_node_or_null(service_slot.marker) is Marker3D
		):
			messages.append(
				"Smart Object slot %s requires Marker3D: %s"
				% [service_slot.slot_id, service_slot.marker]
			)
	var operation_ids: Dictionary[StringName, bool] = { }
	if definition.affordances.is_empty():
		messages.append("Smart Object requires at least one affordance")
	for affordance: DEF_SmartAffordance in definition.affordances:
		if affordance == null or affordance.affordance_id.is_empty():
			messages.append("Smart Object affordance requires a stable ID")
			continue
		if operation_ids.has(affordance.affordance_id):
			messages.append("Duplicate Smart Object affordance: %s" % affordance.affordance_id)
		operation_ids[affordance.affordance_id] = true
		if not slot_ids.has(affordance.slot_id):
			messages.append(
				"Smart Object affordance %s references missing slot %s"
				% [affordance.affordance_id, affordance.slot_id]
			)
		if affordance.executor == null or affordance.executor.get_script() == DEF_InteractionAction:
			messages.append(
				"Smart Object affordance %s requires a concrete executor" % affordance.affordance_id
			)
		elif affordance.executor.timing != null:
			messages.append(
				"Smart Object executor uses explicit acquire/execute/cancel, not input timing"
			)
		elif affordance.executor is DEF_SmartObjectAction:
			messages.append("Smart Object input adapter cannot recursively be its own executor")
		for capability: Script in affordance.required_actor_components:
			if capability == null or not _is_component_script(capability):
				messages.append("Smart Object eligibility requires Component scripts")
	return messages


static func _is_component_script(capability: Script) -> bool:
	var candidate: Script = capability
	while candidate != null:
		if candidate == Component:
			return true
		candidate = candidate.get_base_script()
	return false
#endregion
