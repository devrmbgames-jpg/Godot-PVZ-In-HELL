extends Resource
## Постоянное предложение и обязательство доставки настоящей коробки.
class_name NpcHomeDelivery

## REFUSED — отказ получателя у двери; DECLINED — отказ игрока от предложения.
enum Status { ACCEPTED, DELIVERED, REFUSED, FAILED, OFFERED, DECLINED, EXPIRED }
## Канал предложения определяет доступность сведений терминалу.
enum Source { TERMINAL, PERSONAL }
## Однократный ответ на просьбу увеличить доплату.
enum Bargain { NONE, ACCEPTED, DECLINED }

## Постоянный ID обязательства также служит ключом однократной доплаты.
@export var job_id: StringName = &""
## Постоянный получатель; смена жителя по адресу его не заменяет.
@export var npc_id: StringName = &""
## Выдача и финансовые результаты принадлежат обычному посылочному случаю.
@export var visit_id: StringName = &""
## Скрытый ID физической посылки; номер выдачи может переиспользоваться.
@export var package_id: String = ""
## ID постоянной истории для отображения сведений после исчезновения коробки.
@export var package_history_id: String = ""
## Терминальное или личное предложение; личное по умолчанию остаётся частным.
@export var source: Source = Source.PERSONAL
## Только опубликованные сведения доступны терминалу.
@export var published: bool = false
## Необязательное авторское назначение, например сюжетная доставка.
@export var scenario_id: StringName = &""
## Адрес, зафиксированный при обещании доставки.
@export var address_id: StringName = &""
## Номер заказа для списка доставок после исчезновения успешно выданной коробки.
@export var order_number: int = 0
## Срок обязательства — сон в этот день; таймера в секундах нет.
@export var day_index: int = 1
## Следующее утро: принятая доставка должна завершиться до сна накануне.
@export var deadline_day: int = 2
## Исходная доплата, зафиксированная при создании предложения.
@export var base_bonus: int = 0
## Согласованная доплата; обычная оплата выдачи хранится в CustomerVisit.
@export var bonus: int = 0
## Сохраняемый результат однократного торга; повтор не увеличивает сумму снова.
@export var bargain: Bargain = Bargain.NONE
## Зафиксированный бросок торга от 0 включительно до 1 исключительно.
@export var bargain_roll: float = 0.0
## Сохраняемый итог выполнения или нарушения обязательства.
@export var status: Status = Status.ACCEPTED
## Согласованная доплата уже зафиксирована отдельной денежной операцией.
@export var bonus_committed: bool = false
