extends RefCounted
## Minimal native main-level shell retaining its complete authored raw-body catalog.


#region Native save catalog without gameplay startup
## Keeps native parents, identities and bodies while tests provide their own World/session.
static func create_shell() -> Node3D:
	var packed: PackedScene = load(GameSessionService.MAIN_LEVEL) as PackedScene
	var level: Node3D = packed.instantiate() as Node3D
	# Strip before entering the tree: no level startup, autosave or Entity registration runs.
	level.set_script(null)
	var actors: Node = level.get_node("Entityes")
	var props: Node = actors.get_node("Props")
	for child: Node in props.get_children():
		if child is RigidBody3D:
			var identity: String = RawPhysicsActorService.actor_id(child as RigidBody3D)
			if identity.begins_with("placed/"):
				continue
		child.free()
	for child: Node in actors.get_children():
		if child != props:
			child.free()
	for child: Node in level.get_children():
		if child != actors:
			child.free()
	return level
#endregion
