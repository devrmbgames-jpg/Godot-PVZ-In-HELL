@tool
extends E_TraitedEntity
## Основа автономной нефизической опасности с авторским определением сцены.
class_name E_Hazard

## Авторские настройки prefab; фабрика может выбрать определение из запроса.
@export var definition: DEF_Hazard = null
