extends Resource
## Обязательство доставки настоящей коробки; статус и доплата переживают повтор записи.
class_name NpcHomeDelivery

enum Status { ACCEPTED, DELIVERED, REFUSED, FAILED }

## Постоянный ID обязательства также служит ключом однократной доплаты.
@export var job_id: StringName = &""
## Постоянный получатель; смена жителя по адресу его не заменяет.
@export var npc_id: StringName = &""
## Выдача и финансовые результаты принадлежат обычному посылочному случаю.
@export var visit_id: StringName = &""
## Адрес, зафиксированный при обещании доставки.
@export var address_id: StringName = &""
## Номер заказа для списка доставок после исчезновения успешно выданной коробки.
@export var order_number: int = 0
## Срок обязательства — сон в этот день; таймера в секундах нет.
@export var day_index: int = 1
## Сохраняемый итог выполнения или нарушения обязательства.
@export var status: Status = Status.ACCEPTED
## Доплата в размере базовой выдачи уже зафиксирована.
@export var bonus_committed: bool = false
