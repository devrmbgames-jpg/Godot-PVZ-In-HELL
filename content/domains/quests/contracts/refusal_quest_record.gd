extends Resource
## Постоянные факты задания; живые связи с выдавшим NPC и посылкой принадлежат Relationships.
class_name RefusalQuestRecord

enum State { OFFERED, ACTIVE, COMPLETED, FAILED, IGNORED, EXPIRED }
## Immutable authored variant reference; reward/deadline remain the accepted operation snapshots.
@export var definition: DEF_RefusalQuest = null
## Неповторяющийся ID задания для исхода и выплаты.
@export var quest_id: StringName = &""
## Постоянный ключ торговой роли, выдавшей задание.
@export var issuer_key: StringName = &""
## Скрытый ID настоящей посылки.
@export var package_id: String = ""
## ID случая обслуживания, по которому определяется реальный отказ.
@export var visit_id: StringName = &""
## Снимок регистрационного номера для показа игроку.
@export var display_number: int = 0
## Игровой день предложения, начиная с 1.
@export var offered_day: int = 1
## Последний допустимый день; неразрешённое задание истекает его ночью.
@export var deadline_day: int = 2
## Единственное постоянное состояние предложения/исхода.
@export var state: State = State.OFFERED
## День разрешения задания; 0 до исхода.
@export var resolved_day: int = 0
## Награда в целых денежных единицах.
@export var reward: int = 60
## Кошелёк принял выплату или подтвердил тот же повторный запрос.
@export var reward_paid: bool = false
