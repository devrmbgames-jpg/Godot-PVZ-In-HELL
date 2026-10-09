extends GameDefinition
## Авторская домашняя засада: подсказка предложения, радиус и явная однократная встреча.
class_name DEF_NpcDeliveryScenario

## Предупреждение до принятия; не сообщает скрытый итог встречи.
@export_multiline var offer_hint: String = ""
## Видимая реплика перед нападением.
@export_multiline var ambush_message: String = ""
## Дистанция видимого игрока от NPC для начала засады, в метрах.
@export_range(0.5, 8.0) var ambush_radius: float = 3.0
