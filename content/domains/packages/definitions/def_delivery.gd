@tool
extends GameDefinition
## Авторская поставка: ассортимент, размер дневной партии и лимит ожидающих коробок.
class_name DEF_Delivery

## Ассортимент; дневная партия последовательно меняет начальную позицию в списке.
@export var packages: Array[DEF_Package] = []
## Immutable orderable item catalog; recipient category weights select once per prepared parcel.
@export var order_catalog: Array[DEF_InventoryItem] = []
## Native packing catalog for ordinary supply and isolated NPC rooms; never mutated at runtime.
@export var packing_profiles: Array[DEF_PackagePacking] = [
	preload("res://content/domains/packages/definitions/def_packing_small_a.tres"),
	preload("res://content/domains/packages/definitions/def_packing_small_b.tres"),
	preload("res://content/domains/packages/definitions/def_packing_medium.tres"),
	preload("res://content/domains/packages/definitions/def_packing_large.tres"),
	preload("res://content/domains/packages/definitions/def_packing_barrel.tres"),
	preload("res://content/domains/packages/definitions/def_packing_long.tres"),
]
## Максимальное количество новых коробок за одну утреннюю поставку.
@export_range(1, 50) var maximum_batch_packages: int = 5
## Лимит коробок, за которыми ещё должен прийти живой получатель.
@export_range(1, 500) var maximum_waiting_packages: int = 50
## Доля рыночной стоимости свободного обратного груза, в процентах; округляется вниз.
@export_range(0, 100) var truck_resale_percent: int = 10
