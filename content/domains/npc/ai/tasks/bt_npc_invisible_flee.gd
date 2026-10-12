@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_cloud_flee.gd"
## Native alternative selected by the tree after confirmed player sight is lost.


#region Selected flight appearance
func _form() -> C_NpcVeil.Form:
	return C_NpcVeil.Form.INVISIBLE
#endregion
