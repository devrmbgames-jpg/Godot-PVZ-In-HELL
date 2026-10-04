extends RefCounted
## Общий интерфейс UI; уличный и клиентский контексты обращаются к своим сервисам.
class_name NpcDialogueContext

#region Интерфейс контекста
func _init(_actor: Entity = null, _interlocutor: Entity = null) -> void:
	pass

## Начинает конкретное взаимодействие после проверки условий.
func begin() -> bool:
	return false

## Освобождает участников, не владея модальным захватом ввода.
func end() -> void:
	pass

## Проверяет текущих участников и условия предметной области.
func is_valid() -> bool:
	return false

## Проверяет возможность продолжения диалогового UI.
func can_continue() -> bool:
	return false

## Сохраняет авторский текст, пока конкретный адаптер не изменяет восприятие игрока.
func perceived_text(actual_text: String) -> String:
	return actual_text

## Применяет смысл ответа через конкретный игровой адаптер.
func apply_response_tags(_tags: PackedStringArray) -> bool:
	return false
#endregion
