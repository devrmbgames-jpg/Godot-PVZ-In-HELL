extends Component
## Авторская торговая роль, ассортимент и место выдачи мебели.
class_name C_Trader

## Авторский ID торговой роли.
@export var trader_key: StringName = &"evening_trader"
## Прежний ассортимент, используемый при отсутствии profile.
@export var catalog: Array[DEF_InventoryItem] = []
## При наличии профиль заменяет прежний catalog, сохраняя совместимость сцен.
@export var profile: DEF_TraderProfile = null
## Путь от торговца к месту физической выдачи мебели.
@export var furniture_pickup_path: NodePath = NodePath("FurniturePickup")
