extends Resource
## Одно обещанное физическое изделие; emitted не откатывается после исчезновения тела.
class_name CraftingOutput

## Точный durable контракт однократной выдачи и получения.
const SAVE_FIELDS: Array[String] = ["entity_id", "definition", "emitted", "taken"]

## Устойчивый ID, заранее выделенный принятой партией.
@export var entity_id: String = ""
## Неизменяемое определение физического результата, по одному экземпляру на запись.
@export var definition: DEF_InventoryItem = null
## Тело уже было зарегистрировано; отсутствие тела не даёт повторной выдачи.
@export var emitted: bool = false
## Изделие забрали/вынесли/израсходовали после выдачи; повтор не создаёт его заново.
@export var taken: bool = false
