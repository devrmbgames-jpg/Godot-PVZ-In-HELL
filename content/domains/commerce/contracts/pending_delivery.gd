extends Resource
## Оплаченный заказ с датой доставки и однократной отметкой исполнения.
class_name PendingDelivery

## Устойчивый ID оплаченного заказа.
@export var delivery_id: StringName = &""
## Определение физического товара для доставки.
@export var item: DEF_InventoryItem = null
## Количество единиц; мебель доставляется по одному экземпляру.
@export var quantity: int = 1
## День оплаты заказа, начиная с 1.
@export var ordered_day: int = 1
## Первый день допустимой выдачи; занятое место откладывает исполнение.
@export var delivery_day: int = 2
## Доставка создана физически; повторное создание запрещено.
@export var fulfilled: bool = false
