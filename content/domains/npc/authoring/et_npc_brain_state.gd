@tool
extends EntityTrait
## Compiles native decision/sensor state, combat Profile defaults and authored fire resistance.
class_name ET_NpcBrainState

#region Required capability inputs
func _init() -> void:
	trait_id = &"npc_brain_state"
	required_root_class = &"RigidBody3D"
	required_components = [C_NpcIdentity, C_NpcCombat]


## Requires the same immutable roster Profile used by identity and movement construction.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	if not context.definitions.get(&"npc_profile") is DEF_NpcProfile:
		return PackedStringArray(["NPC brain state requires the roster's NPC Profile"])
	return PackedStringArray()
#endregion

#region Pure brain and immunity recipes
## Supplies fresh decision/route state and durable resistance before damage/AI consumers react.
func recipes_for(context: EntitySpawnContext) -> Array[Component]:
	var resistance: C_DamageResistance = C_DamageResistance.new()
	var profile: DEF_NpcProfile = context.definitions.get(&"npc_profile") as DEF_NpcProfile
	if profile != null and profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null:
		resistance.multipliers[DamageRequest.Type.FIRE] = 0.0
	return [C_NpcAwareness.new(), C_NpcDecision.new(), C_NpcRoute.new(), resistance]


## Configures existing scene combat capability without installing an engine runner or ticking AI.
func configuration_for(context: EntitySpawnContext) -> Dictionary[Script, Dictionary]:
	var profile: DEF_NpcProfile = context.definitions.get(&"npc_profile") as DEF_NpcProfile
	if profile == null:
		return {}
	return {C_NpcCombat as Script: {
		&"melee_attacks": profile.melee_attacks,
		&"ranged_attacks": profile.ranged_attacks,
		&"automatic_attack_selection": false,
	}}
#endregion
