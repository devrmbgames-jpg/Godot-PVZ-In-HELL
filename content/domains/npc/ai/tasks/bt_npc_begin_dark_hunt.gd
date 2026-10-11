@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Binds one perceived target through the existing social/combat operation without an offense.


#region Explicit hunt start
func _tick(_delta: float) -> Status:
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if (
		not _awareness.player_visible or not GrabQueries.holder_available(player)
		or player.has_component(C_Death)
	):
		return FAILURE
	if not _claim("Охота в темноте"):
		return FAILURE
	_awareness.fleeing = false
	NpcSocialService.apply_reaction(_actor, player, NpcMemory.Reaction.ATTACK)
	if CombatQueries.target_for(_actor) != player:
		return FAILURE
	_awareness.target_visible = true
	return SUCCESS
#endregion
