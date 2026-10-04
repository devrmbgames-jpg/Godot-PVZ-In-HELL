extends Label3D
## Presentation of the trader's authored store policy; commerce owns all transactions.

const REFRESH_SECONDS: float = 0.25

var _remaining: float = 0.0
@onready var _trader: Entity = get_parent() as Entity


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0:
		return

	_remaining = REFRESH_SECONDS
	var shop: C_Trader = _trader.get_component(C_Trader) as C_Trader
	visible = shop != null and not _trader.has_component(C_Death)
	if not visible:
		return

	var name_text: String = shop.profile.display_name if shop.profile != null else "Торговец"
	var state_text: String = "Открыто" if TraderCatalogService.is_open(shop, DayPhaseService.current()) else "Закрыто"
	text = "%s · %s\n%s" % [name_text, state_text, TraderCatalogService.schedule_text(shop)]
