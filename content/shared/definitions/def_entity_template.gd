@tool
extends GameDefinition
## Optional editor-only preset; runtime compilation reads the Entity's direct traits export.
class_name DEF_EntityTemplate

## Reusable preset entries copied into an Entity; this resource is never a runtime provider.
@export var traits: Array[EntityTrait] = []
