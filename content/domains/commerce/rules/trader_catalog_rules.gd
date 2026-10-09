extends RefCounted
## Reads the sole authored Trader Profile assortment and schedule without gameplay mutations.
class_name TraderCatalogRules

#region Assortment and availability
## Returns the authored Profile array for read-only use by transactions and presentation.
static func catalog(shop: C_Trader) -> Array[DEF_InventoryItem]:
	assert(shop.profile != null, "Trader roles require an authored DEF_TraderProfile")
	return shop.profile.catalog


## Checks the authored day interval and phase mask; technical Night is always closed.
static func is_open(shop: C_Trader, cycle: C_DayCycle) -> bool:
	if shop == null or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return false

	var profile: DEF_TraderProfile = shop.profile
	assert(profile != null, "Trader roles require an authored DEF_TraderProfile")
	if profile.first_day < 1 or profile.repeat_days < 1 or cycle.day_index < profile.first_day:
		return false

	var scheduled_day: bool = (cycle.day_index - profile.first_day) % profile.repeat_days == 0
	var scheduled_phase: bool = (profile.open_phases & (1 << cycle.phase)) != 0
	return scheduled_day and scheduled_phase


## Checks the authored delivery permission and explicit bulky-furniture offer kind.
static func can_deliver(shop: C_Trader, item: DEF_InventoryItem) -> bool:
	if shop == null or item == null:
		return false
	assert(shop.profile != null, "Trader roles require an authored DEF_TraderProfile")
	return (
		shop.profile.home_delivery_enabled
		and item.kind == DEF_InventoryItem.Kind.FURNITURE and item.bulky_furniture
	)


## Formats the authored trading schedule for presentation.
static func schedule_text(shop: C_Trader) -> String:
	var profile: DEF_TraderProfile = shop.profile
	assert(profile != null, "Trader roles require an authored DEF_TraderProfile")
	var phases: Array[String] = []
	for phase: int in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		if profile.open_phases & (1 << phase):
			phases.append(C_DayCycle.Phase.keys()[phase])
	return "С дня%d, каждые%d дн. · %s" % [profile.first_day, profile.repeat_days, "/".join(phases)]
#endregion
