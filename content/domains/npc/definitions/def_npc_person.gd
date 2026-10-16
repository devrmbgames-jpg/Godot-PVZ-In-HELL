@tool
extends GameDefinition
## Неизменная авторская личность; key задаёт постоянный npc/N, а не позицию в составе.
class_name DEF_NpcPerson

## Черновая карточка для технической проверки; не означает утверждённого персонажа.
@export var prototype: bool = true
## Архетип владеет врождёнными возможностями и базовыми физическими настройками.
@export var profile: DEF_NpcArchetype = null
## Явная сцена тела; личность не выбирает её по seed или порядку профилей.
@export_file("*.tscn") var npc_scene_path: String = ""
## Фиксированные имя, диалог, совместимые черты и множители; runtime получает отдельную копию.
@export var variation: NpcVariation = null
## Постоянный ключ получателя; не меняется вместе с заказом или телом.
@export var recipient_key: StringName = &""
## Постоянный дом жителя; у возвращающегося гостя пуст.
@export var home_id: StringName = &""
## Авторский проход прибытия в район.
@export var portal_id: StringName = &""
## Авторский проход ухода из района.
@export var exit_id: StringName = &""
