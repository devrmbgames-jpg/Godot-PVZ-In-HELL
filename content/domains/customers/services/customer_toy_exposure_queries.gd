extends RefCounted
## Recognizes only an actual held or unpacked inspection item that the player can physically see.
class_name CustomerToyExposureQueries


#region Actual physical toy visibility
## Closed parcel definitions and distant unrelated toys never reveal private contents.
static func exposed_toy_id(
	actor: E_DistrictNpc,
	player: Entity,
	person: NpcRecord,
	rule: DEF_NpcStrengthPride,
) -> String:
	if not NpcPerceptionService.can_see(actor, player, person):
		return ""
	for slot: int in 3:
		var held: Entity = GrabQueries.held_in_slot(actor, slot)
		if _visible_toy(held, player, rule):
			return held.id
	for item: Entity in CustomerInspectionQueries.cargo(actor):
		if _visible_toy(item, player, rule):
			return item.id
	return ""


static func _visible_toy(item: Entity, player: Entity, rule: DEF_NpcStrengthPride) -> bool:
	if not EntityAvailability.contains(item, ECS.world):
		return false
	var contents: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	return (
		contents != null and contents.definition != null
		and (contents.definition.categories & DEF_InventoryItem.Category.TOY) != 0
		and NpcCameraVisibility.item_observed(item, player, rule.toy_visibility_mask)
	)
#endregion
