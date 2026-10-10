extends Resource
## Сохранённый результат предмета обратного груза; живых ссылок на Entity не содержит.
class_name TruckCargoReceipt

enum Kind {
	RETURN,
	SALE,
	DISPOSAL,
}

## ID партии приёмки, в которой зафиксирован предмет.
@export var batch_id: String = ""
## Устойчивый Entity.id, сохраняемый штатным snapshot.
@export var entity_id: String = ""
## День фактической отправки, начиная с 1.
@export var day_index: int = 1
## Возврат складской коробки, продажа имущества либо утилизация без дохода.
@export var kind: Kind = Kind.DISPOSAL
## Зафиксированная цена в целых денежных единицах; после удаления не пересчитывается.
@export var amount: int = 0
## Физический предмет уже удалён через World; повтор не удаляет иной предмет.
@export var removed: bool = false
## Расчёт после удаления завершён, включая нулевую выручку.
@export var settled: bool = false
