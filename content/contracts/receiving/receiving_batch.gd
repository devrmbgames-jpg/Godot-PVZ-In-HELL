extends Resource
class_name ReceivingBatch

enum Source {
	BASE_SUPPLY,
	PENDING_ORDER,
}

@export var source: Source = Source.BASE_SUPPLY
@export var day_index: int = 0
@export var next_package: int = 0
