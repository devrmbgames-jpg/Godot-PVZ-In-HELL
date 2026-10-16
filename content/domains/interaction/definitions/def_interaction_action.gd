extends GameDefinition
## Авторский контракт действий; runtime прогресс хранится в Components/Relationships.
## Конкретные временные адаптеры могут нести параметры выбранной команды без мутации shared asset.
class_name DEF_InteractionAction

enum Slot {
	INTERACT,
	USE,
	PRIMARY,
	SECONDARY,
}

## Постоянный ключ действия, в том числе для сохранённого прогресса.
@export var action_id: StringName = &""
## Смысловой канал ввода, выбираемый resolver.
@export var slot: Slot = Slot.USE
## Авторская подпись действия для подсказки игроку.
@export var caption: String = "Использовать"
## Приоритет среди доступных действий; большее значение выбирается первым.
@export var priority: int = 0
## Разрешает исполнение при удержании кнопки, а не только на её нажатии.
@export var continuous: bool = false
## Разрешает старый запасной переход Interact → Use; отключается для разных по смыслу кнопок.
@export var allow_interact_fallback: bool = true
## Необязательные правила длительного действия; null означает обычное исполнение.
@export var timing: DEF_ProlongedInteraction = null


#region Контракт доступности и исполнения
## Returns a read-only contextual caption; authored captions remain immutable and are the default.
func caption_for(_actor: Entity, _source: Entity, _target: Entity) -> String:
	return caption


## Разрешает доступному контекстному Interact опередить обычное отпускание Carry.
func allows_carry_interaction() -> bool:
	return false


## Проверяет доступность; обработчик не хранит состояние, изменяемые данные принадлежат Components.
func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return false


## Исполняет действие через игровые сервисы; базовый обработчик не выполняет эффект.
func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	pass


## Повторно проверяет доступность и исполняет; переопределяется, если сам эффект может
## завершиться отказом.
## Базовый true означает вызов execute после eligibility; отдельного подтверждения эффекта нет.
func complete(actor: Entity, source: Entity, target: Entity) -> bool:
	if not is_available(actor, source, target):
		return false

	execute(actor, source, target)
	return true

#endregion
