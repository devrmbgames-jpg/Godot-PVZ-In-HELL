extends Resource
## Зафиксированный предмет ожидающей партии; содержит устойчивые ID и данные без живых Node.
class_name PendingLootDrop

#region Постоянные данные
## ID однократно подготовленной партии.
@export var batch_id: String = ""
## Постоянный ID предмета; используется также ключом физического экземпляра.
@export var drop_id: String = ""
## Путь заранее выбранного физического prefab.
@export var scene_path: String = ""
## Мировая точка выпадения, сохраняющаяся после удаления источника.
@export var origin: Vector3 = Vector3.ZERO
## Исходная точка источника; кандидат не должен появиться по другую сторону стены.
@export var anchor: Vector3 = Vector3.ZERO
## Стабильный Entity.id источника, если он ещё существует.
@export var source_id: String = ""
## Стабильный Entity.id инициатора для обычных опасностей.
@export var actor_id: String = ""
## ID посылки для осмотра и исходных опасностей; пустой для останков.
@export var package_id: String = ""
## Выпадение над коробкой сохраняет высоту вместо прижатия к полу.
@export var airborne: bool = false
## Исключать отключаемое мёртвое тело из физической проверки.
@export var ignore_source: bool = false
## Исходная скорость выброса; применяется только при первом реальном размещении.
@export var velocity: Vector3 = Vector3.ZERO
## Активировать штатный emitter извлечённого предмета после размещения.
@export var activate_hazard: bool = false
## Первый предмет принимает следование существующих опасностей упаковки.
@export var primary: bool = false
## Необязательная сцена эффекта первого вскрытия, исполняемого при размещении первого предмета.
@export var opening_hazard_path: String = ""
#endregion
