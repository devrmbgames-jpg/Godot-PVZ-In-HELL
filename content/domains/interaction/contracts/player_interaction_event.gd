extends RefCounted
## Подтверждённый переход взаимодействия игрока; событие направляется затронутому объекту.
class_name PlayerInteractionEvent

## Канал World с подтверждённым взаимодействием игрока.
const EVENT: StringName = &"player_interaction"

enum Kind { TERMINAL_OPENED, TERMINAL_CLOSED, PARCEL_PICKED, PARCEL_PLACED, DOOR_OPENED, DOOR_CLOSED }

## Вид уже состоявшегося перехода.
var kind: Kind = Kind.TERMINAL_OPENED
## Живой актор на момент публикации; доступность проверяет подписчик.
var actor: Entity = null
## Затронутый объект на момент публикации.
var object: Entity = null
## Стабильный ID актора, доступный после исчезновения Node.
var actor_id: String = ""
## Стабильный ID объекта, доступный после исчезновения Node.
var object_id: String = ""
## Доменный ID посылки для событий переноски коробки.
var package_id: String = ""
## Transient committed-fact identity for correlation; not a second gameplay ledger.
var operation_id: StringName = &""
