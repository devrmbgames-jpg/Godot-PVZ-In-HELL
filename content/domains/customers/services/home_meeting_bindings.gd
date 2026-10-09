extends RefCounted
## Owns explicit release of live home meeting bindings, without deciding delivery outcomes.
class_name HomeMeetingBindings

#region Live home meeting release
## Снимает только резервирование встречи, не перемещая коробку.
static func release_meeting(body: Entity) -> void:
	for link: Relationship in body.relationships.duplicate():
		if link.relation is R_NpcHomeMeeting:
			body.remove_relationship(link)
#endregion
