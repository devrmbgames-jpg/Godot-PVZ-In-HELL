extends Resource
## One remembered incident with recognized stable participants and a cached reaction.
class_name NpcMemory

enum Kind { HELP, THREAT, LIE, BROKEN_PROMISE, ATTACK, KILLING, JOKE, SUBMISSION, OFFENSE }
enum Reaction { TALK, ACCEPT, ATTACK, FLEE, RESPECT }

## Stable incident identity; repeated presentation cannot reroll the reaction.
@export var incident_id: StringName = &""
## Recognized actor, not a live Node reference.
@export var actor_id: StringName = &""
## Recognized victim where applicable.
@export var victim_id: StringName = &""
## Remembered type of action.
@export var kind: Kind = Kind.HELP
## Day when it was observed.
@export var day: int = 1
## One-time authored social response.
@export var reaction: Reaction = Reaction.TALK
