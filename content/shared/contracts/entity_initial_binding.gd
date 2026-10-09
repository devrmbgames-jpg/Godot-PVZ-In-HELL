@tool
extends Resource
## Immutable authoring intent for one initial Relationship; live binding follows endpoint fixup.
class_name EntityInitialBinding

## Data-only Relationship recipe; runtime materialization makes a fresh instance.
@export var relation: Component = null
## Named context endpoint required by this Relationship.
@export var endpoint: StringName = &""
## Allows an intentionally absent endpoint without weakening mandatory binding validation.
@export var optional: bool = false
