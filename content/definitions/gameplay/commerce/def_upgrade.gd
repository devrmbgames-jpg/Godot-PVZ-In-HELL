extends GameDefinition
## Future upgrade offer; R20 authors data only.
class_name DEF_Upgrade

@export var display_name: String = "Улучшение"
@export_range(0, 1000000000) var market_price: int = 100
