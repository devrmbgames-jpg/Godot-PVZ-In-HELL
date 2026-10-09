@tool
extends GameDefinition
## Авторская поставка: ассортимент, размер дневной партии и лимит ожидающих коробок.
class_name DEF_Delivery

## Ассортимент; дневная партия последовательно меняет начальную позицию в списке.
@export var packages: Array[DEF_Package] = []
## Максимальное количество новых коробок за одну утреннюю поставку.
@export_range(1, 50) var maximum_batch_packages: int = 5
## Лимит коробок, за которыми ещё должен прийти живой получатель.
@export_range(1, 500) var maximum_waiting_packages: int = 50
