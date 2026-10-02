extends Footstepper
## Addon manual mode assigns an arbitrary parent to a CharacterBody3D field.
## Keep the addon read-only and allow its manual audio API under rigid NPC presentation.
class_name CharacterFootstepper


func _check_parent() -> void:
	if is_manual:
		parent = get_parent() as CharacterBody3D
		return
	super._check_parent()
