extends Resource
## Воспринятый инцидент с постоянными ID участников и сохранённой реакцией.
class_name NpcMemory

enum Kind { HELP, THREAT, LIE, BROKEN_PROMISE, ATTACK, KILLING, JOKE, SUBMISSION, OFFENSE }
enum Reaction { TALK, ACCEPT, ATTACK, FLEE, RESPECT }

## Постоянный ID инцидента; повторный показ не перебрасывает реакцию.
@export var incident_id: StringName = &""
## ID распознанного участника, без ссылки на живой Node.
@export var actor_id: StringName = &""
## ID распознанной жертвы, если событие имеет жертву.
@export var victim_id: StringName = &""
## Вид запомненного действия.
@export var kind: Kind = Kind.HELP
## День, когда участник воспринял событие.
@export var day: int = 1
## Реакция на социальный инцидент, выбранная один раз.
@export var reaction: Reaction = Reaction.TALK
