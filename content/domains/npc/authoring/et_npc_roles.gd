@tool
extends EntityTrait
## Compiles resident inventory/hunger/actions and an explicitly sourced merchant capability.
class_name ET_NpcRoles

## Each reusable provider is explicitly authored; a missing scene provider never triggers fallback.
enum Provider {
	TRAIT,
	SCENE,
}

## Selects whether this Trait supplies actions or merges the authored scene action list.
@export var action_set_provider: Provider = Provider.TRAIT
## Selects whether a merchant's Trader Component comes from this Trait or the existing scene.
@export var trader_provider: Provider = Provider.TRAIT
## Immutable policy for the resident's constructed hunger state.
@export var hunger_policy: DEF_HungerPolicy = null
## Immutable street dialogue action, appended once to the initial action list.
@export var street_action: DEF_NpcDialogueAction = null
## Immutable trade action supplied only with the Trait-owned merchant provider.
@export var trade_action: DEF_TraderAction = null
## Immutable optional role actions placed before intrinsic street/trade actions.
## Their availability contracts keep inactive roles out of interaction choices.
@export var additional_actions: Array[DEF_InteractionAction] = []
## Sole Trader tuning owner in TRAIT mode; SCENE mode requires this field to remain empty.
@export var trader_profile: DEF_TraderProfile = null


#region Explicit provider contract
func _init() -> void:
	trait_id = &"npc_roles"
	required_root_class = &"RigidBody3D"
	required_components = [C_NpcIdentity]


## Validates captured Profiles, immutable action recipes and the selected authored providers.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	var issues: PackedStringArray = []
	var profile: DEF_NpcProfile = context.definitions.get(&"npc_profile") as DEF_NpcProfile
	if profile == null or not context.definitions.get(&"district_definition") is DEF_District:
		issues.append("Resident roles require explicit NPC and district Profiles")
	if hunger_policy == null or street_action == null:
		issues.append("Resident roles require hunger policy and street action")
	if trader_provider == Provider.SCENE and trader_profile != null:
		issues.append("Scene-owned Trader Profile cannot have a competing Trait Profile")

	var additional_ids: Dictionary[StringName, bool] = { }
	for action: DEF_InteractionAction in additional_actions:
		if action == null or action.action_id.is_empty():
			issues.append("Additional role actions require Definitions with action IDs")
			continue
		var duplicate_id: bool = (
			additional_ids.has(action.action_id)
			or (street_action != null and action.action_id == street_action.action_id)
			or (trade_action != null and action.action_id == trade_action.action_id)
		)
		if duplicate_id:
			issues.append("Additional role actions cannot duplicate an initial action ID")
		additional_ids[action.action_id] = true

	if action_set_provider == Provider.SCENE:
		var scene_actions: C_InteractionActionSet = _scene_component(
			context,
			C_InteractionActionSet,
		) as C_InteractionActionSet
		if scene_actions == null:
			issues.append("SCENE action provider requires authored C_InteractionActionSet")
		elif street_action != null:
			for action: DEF_InteractionAction in scene_actions.actions:
				if action == null:
					issues.append("Scene actions require valid immutable Definitions")
				elif action.action_id == street_action.action_id \
						or additional_ids.has(action.action_id):
					issues.append("Scene actions cannot duplicate another initial action ID")
	if profile != null and profile.merchant:
		if not context.actor.get_node_or_null("FurniturePickup") is Marker3D:
			issues.append("Merchant requires scene-owned FurniturePickup marker")
		if trader_provider == Provider.SCENE:
			if _scene_component(context, C_Trader) == null:
				issues.append("SCENE merchant provider requires authored C_Trader")
		elif trader_profile == null or trade_action == null:
			issues.append("TRAIT merchant provider requires Trader Profile and trade action")
	return issues
#endregion


#region Pure resident and merchant recipes
## Supplies fresh aggregate state without installing live Components or engine nodes.
func recipes_for(context: EntitySpawnContext) -> Array[Component]:
	var recipes: Array[Component] = [C_Inventory.new(), C_Hunger.new()]
	if action_set_provider == Provider.TRAIT:
		recipes.append(C_InteractionActionSet.new())
	var profile: DEF_NpcProfile = context.definitions.get(&"npc_profile") as DEF_NpcProfile
	if profile != null and profile.merchant and trader_provider == Provider.TRAIT:
		var trader: C_Trader = C_Trader.new()
		trader.profile = trader_profile
		recipes.append(trader)
	return recipes


## Initial hunger comes from the explicit district owner; saved fields overlay these defaults.
## Optional role actions precede retained scene Definitions and the appended street action.
func configuration_for(context: EntitySpawnContext) -> Dictionary[Script, Dictionary]:
	var fields: Dictionary[Script, Dictionary] = { }
	var district: DEF_District = context.definitions.get(&"district_definition") as DEF_District
	if district != null:
		fields[C_Hunger as Script] = {
			&"policy": hunger_policy,
			&"value": district.npc_start_hunger,
		}
	var actions: Array[DEF_InteractionAction] = additional_actions.duplicate()
	if action_set_provider == Provider.SCENE:
		var scene_actions: C_InteractionActionSet = _scene_component(
			context,
			C_InteractionActionSet,
		) as C_InteractionActionSet
		if scene_actions != null:
			actions.append_array(scene_actions.actions)
	if street_action != null:
		actions.append(street_action)
	var profile: DEF_NpcProfile = context.definitions.get(&"npc_profile") as DEF_NpcProfile
	if profile != null and profile.merchant and trader_provider == Provider.TRAIT:
		if trade_action != null:
			actions.append(trade_action)
	fields[C_InteractionActionSet as Script] = { &"actions": actions }
	return fields


func _scene_component(context: EntitySpawnContext, component_script: Script) -> Component:
	for recipe: Component in context.actor.component_resources:
		if recipe.get_script() == component_script:
			return recipe
	return null
#endregion
