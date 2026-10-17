@tool
extends GameDefinition
## Только авторские настройки отдельного мебельного терминала; очередь находится в Component.
class_name DEF_AngelFurnitureShop

## Явный ассортимент мебели; другие физические инструменты не становятся мебелью.
@export var catalog: Array[DEF_InventoryItem] = []
## Постоянный ID домашней площадки, независимо от NodePath/расположения UI.
@export var receiving_id: StringName = &""
## Доступное до оплаты описание места; принятое обещание сохраняет собственную копию.
@export_multiline var receiving_hint: String = ""
