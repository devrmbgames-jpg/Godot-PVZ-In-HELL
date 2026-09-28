extends DEF_InteractionAction
## E/F address mapped primary/secondary hands without a separate input subsystem.
class_name DEF_PhysicalSlotAction

@export var secondary_hand: bool = false
@export var take: bool = false


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var storage: E_PhysicalSlot = source as E_PhysicalSlot
	if storage == null:
		return false
	var hand: int = GrabService.mapped_hand(actor, secondary_hand)
	if not take:
		return PhysicalSlotService.can_store(actor, storage, hand)
	var config: C_PhysicalSlot = storage.get_component(C_PhysicalSlot) as C_PhysicalSlot
	return config != null and GrabService.can_take_from_storage(actor, PhysicalSlotService.occupant(storage), hand, config.allow_hand_replacement)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	complete(actor, source, target)


func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	if not is_available(actor, source, null):
		return false
	var storage: E_PhysicalSlot = source as E_PhysicalSlot
	var hand: int = GrabService.mapped_hand(actor, secondary_hand)
	if not take:
		return PhysicalSlotService.store(actor, storage, hand)
	var config: C_PhysicalSlot = storage.get_component(C_PhysicalSlot) as C_PhysicalSlot
	return GrabService.take_from_storage(actor, PhysicalSlotService.occupant(storage), hand, config.allow_hand_replacement)
