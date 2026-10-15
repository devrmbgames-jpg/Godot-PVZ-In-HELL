extends Resource
## Сохранённый результат предмета обратного груза; живых ссылок на Entity не содержит.
## TruckCargoService пишет receipt до удаления; повтор завершает оставшийся remove/settlement.
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
## Stable identity of a scriptless body; mutually exclusive with Entity.id.
@export var raw_actor_id: String = ""
## День фактической отправки, начиная с 1.
@export var day_index: int = 1
## Возврат складской коробки, продажа имущества либо утилизация без дохода.
@export var kind: Kind = Kind.DISPOSAL
## Зафиксированная цена в целых денежных единицах; после удаления не пересчитывается.
@export var amount: int = 0
## Guard ставится перед native removal, чтобы callbacks видели принятый шаг удаления.
## После возврата из removal повтор этот предмет не удаляет; освобождение Node возможно позже.
@export var removed: bool = false
## TruckCargoService завершил расчёт после удаления, включая нулевую выручку.
@export var settled: bool = false
