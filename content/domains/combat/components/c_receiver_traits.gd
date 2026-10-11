@tool
extends Component
## Authored supernatural receiver capabilities, independent of scene names and shopping categories.
class_name C_ReceiverTraits

enum Trait {
	HOLY_VULNERABLE = 1,
	UNHOLY_HEALING = 2,
	VAMPIRE = 4,
	UNCLEAN = 8,
}

## Independent immutable gameplay tags; NPC archetype composition may supply their combination.
@export_flags("Holy vulnerable", "Unholy healing", "Vampire", "Unclean") var traits: int = 0
