extends RefCounted
## Сопоставляет ID и теги предмета с авторским требованием без выбора или расходования.
class_name ItemAccessRules

#region Authored requirement matching
## Проверяет точный ID и все заданные теги на одном предмете.
static func matches(identity: C_AccessItem, requirement: DEF_AccessRequirement) -> bool:
	if identity == null or requirement == null:
		return false
	if requirement.required_item_id != &"" and identity.item_id != requirement.required_item_id:
		return false

	for tag: StringName in requirement.required_tags:
		if tag == &"" or not identity.tags.has(tag):
			return false
	return true
#endregion
