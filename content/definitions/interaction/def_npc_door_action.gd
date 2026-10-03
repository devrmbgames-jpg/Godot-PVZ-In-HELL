extends DEF_InteractionAction
## Knocking requests the permanent recipient; a second interaction hands over the held real parcel.
class_name DEF_NpcDoorAction

#region Home interaction
## Home jobs can be met during evening, including retry after interrupted approach.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var address: C_NpcAddress = source.get_component(C_NpcAddress) as C_NpcAddress
	return address != null and GrabService.holder_available(actor) and NpcHomeDeliveryService.job_for_address(address.address_id) != null

## Opens or continues the authoritative recipient meeting.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	NpcHomeDeliveryService.knock(actor, source)
#endregion
