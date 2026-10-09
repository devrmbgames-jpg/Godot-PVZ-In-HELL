extends Resource
## Постоянная запись оплаченной покупки без ссылок на живые Entity.
class_name PurchaseReceipt

enum Mode { PURCHASE, ORDER, TRADER_DELIVERY }
## Устойчивый ID покупки; повтор с другими параметрами считается конфликтом.
@export var operation_id: StringName = &""
## Способ покупки: торговец, терминал или доставка торговца.
@export var mode: Mode = Mode.PURCHASE
## Стабильный ключ приобретённого определения.
@export var item_key: StringName = &""
## Оплаченное количество единиц.
@export var quantity: int = 1
## Полная цена в целых денежных единицах, включая delivery_fee.
@export var total_price: int = 0
## Доплата доставки, уже включённая в total_price.
@export var delivery_fee: int = 0
## Игровой день совершения покупки, начиная с 1.
@export var day_index: int = 1
