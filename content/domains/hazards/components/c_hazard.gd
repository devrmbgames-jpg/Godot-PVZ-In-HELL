extends Component
## Данные автономной опасности с авторским определением и постоянной атрибуцией.
class_name C_Hazard

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["definition", "request_id", "origin_id", "instigator_id"]

## Авторское определение, выбранное общей фабрикой.
@export var definition: DEF_Hazard = null
## Устойчивый ID запроса, сохраняемый после удаления источника.
var request_id: String = ""
## Постоянный ID происхождения эффекта.
var origin_id: String = ""
## Постоянный ID инициатора эффекта.
var instigator_id: String = ""
## Необязательный живой инициатор; срок автономного эффекта от него не зависит.
var instigator: Entity = null

## Необязательный источник для исключения его коллайдеров из луча взрыва, отдельно от владения.
var origin: Entity = null
