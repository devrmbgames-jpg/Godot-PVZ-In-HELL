extends Component
## Данные автономной опасности с авторским определением и постоянной атрибуцией.
class_name C_Hazard

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["definition", "request_id", "origin_id", "instigator_id"]

## Immutable авторское определение, выбранное фабрикой; restore восстанавливает ссылку.
@export var definition: DEF_Hazard = null
## Устойчивый ID запроса, сохраняемый после удаления источника.
var request_id: String = ""
## Постоянный ID происхождения эффекта.
var origin_id: String = ""
## Постоянный ID инициатора эффекта.
var instigator_id: String = ""
## Необязательный живой инициатор для атрибуции; не удерживает Node от удаления.
var instigator: Entity = null

## Необязательный источник для исключения его коллайдеров из луча взрыва, отдельно от владения.
var origin: Entity = null
