extends RefCounted
## Read-only authored store policy; no stock or money authority.
class_name TraderCatalogService


static func catalog(shop: C_Trader) -> Array[DEF_InventoryItem]:
	return shop.profile.catalog if shop.profile != null else shop.catalog


static func is_open(shop: C_Trader, cycle: C_DayCycle) -> bool:
	if shop == null or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return false
	var profile: DEF_TraderProfile = shop.profile
	if profile == null:
		return cycle.phase == C_DayCycle.Phase.EVENING
	return profile.first_day > 0 and profile.repeat_days > 0 and cycle.day_index >= profile.first_day and (cycle.day_index - profile.first_day) % profile.repeat_days == 0 and (profile.open_phases & (1 << cycle.phase)) != 0


static func schedule_text(shop: C_Trader) -> String:
	if shop.profile == null:
		return "Каждый день · Evening"
	var phases: Array[String] = []
	for phase: int in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		if shop.profile.open_phases & (1 << phase):
			phases.append(C_DayCycle.Phase.keys()[phase])
	return "С дня%d, каждые%d дн. · %s" % [shop.profile.first_day, shop.profile.repeat_days, "/".join(phases)]
