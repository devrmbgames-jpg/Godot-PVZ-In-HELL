@tool
extends EntityTrait
## Compiles resident inventory/hunger/actions and explicitly authored public shop capabilities.
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
## Public shops by permanent npc/N identity, independent of archetype and legacy merchant job.
## TRAIT mode only; captured identity selects tuning without changing population/home selection.
@export var role_profiles: Dictionary[StringName, DEF_TraderProfile] = { }
## Public-shop entry can outrank a separate buyback action; its panel retains both choices.
## Required with role_profiles; the legacy merchant keeps its own trade_action.
@export var role_trade_action: DEF_TraderAction = null


#region Explicit provider contract
func _init() -> void:
	trait_id = &"npc_roles"
	required_root_class = &"CharacterBody3D"
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
	if trader_provider == Provider.SCENE and not role_profiles.is_empty():
		issues.append("Scene-owned Trader cannot have competing public shop Profiles")
	for key: StringName in role_profiles:
		if key.is_empty() or role_profiles[key] == null:
			issues.append("Public shop mapping requires explicit NPC and Trader Profiles")
	if not role_profiles.is_empty() and role_trade_action == null:
		issues.append("Public shop mapping requires an explicit trade entry action")

	var additional_ids: Dictionary[StringName, bool] = { }
	for action: DEF_InteractionAction in additional_actions:
		if action == null or action.action_id.is_empty():
			issues.append("Additional role actions require Definitions with action IDs")
			continue
		var duplicate_id: bool = (
			additional_ids.has(action.action_id)
			or (street_action != null and action.action_id == street_action.action_id)
			or (trade_action != null and action.action_id == trade_action.action_id)
			or (role_trade_action != null and action.action_id == role_trade_action.action_id)
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
				elif (
					action.action_id == street_action.action_id
					or additional_ids.has(action.action_id)
				):
					issues.append("Scene actions cannot duplicate another initial action ID")
	if profile != null and (profile.merchant or role_profiles.has(_role_owner(context))):
		if not context.actor.get_node_or_null("FurniturePickup") is Marker3D:
			issues.append("Merchant requires scene-owned FurniturePickup marker")
		if trader_provider == Provider.SCENE:
			if _scene_component(context, C_Trader) == null:
				issues.append("SCENE merchant provider requires authored C_Trader")
		elif _shop_profile(context) == null or _trade_action_for(context) == null:
			issues.append("TRAIT merchant provider requires Trader Profile and trade action")
	return issues
#endregion


#region Pure resident and merchant recipes
## Supplies fresh aggregate state without installing live Components or engine nodes.
func recipes_for(context: EntitySpawnContext) -> Array[Component]:
	var recipes: Array[Component] = [C_Inventory.new(), C_Hunger.new()]
	if action_set_provider == Provider.TRAIT:
		recipes.append(C_InteractionActionSet.new())
	if _shop_profile(context) != null and trader_provider == Provider.TRAIT:
		var trader: C_Trader = C_Trader.new()
		trader.profile = _shop_profile(context)
		trader.trader_key = trader.profile.key
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
	if _shop_profile(context) != null and trader_provider == Provider.TRAIT:
		var entry: DEF_TraderAction = _trade_action_for(context)
		if entry != null:
			actions.append(entry)
	fields[C_InteractionActionSet as Script] = { &"actions": actions }
	return fields


func _role_owner(context: EntitySpawnContext) -> StringName:
	# ET_NpcIdentity validates the captured ID/persistent key before native publication.
	var fields: Dictionary = context.initial_fields.get(C_NpcIdentity as Script, { })
	return StringName(fields.get(&"npc_id", &""))


func _shop_profile(context: EntitySpawnContext) -> DEF_TraderProfile:
	var npc_id: StringName = _role_owner(context)
	if role_profiles.has(npc_id):
		return role_profiles[npc_id]
	var profile: DEF_NpcProfile = context.definitions.get(&"npc_profile") as DEF_NpcProfile
	return trader_profile if profile != null and profile.merchant else null


func _trade_action_for(context: EntitySpawnContext) -> DEF_TraderAction:
	return role_trade_action if role_profiles.has(_role_owner(context)) else trade_action


func _scene_component(context: EntitySpawnContext, component_script: Script) -> Component:
	for recipe: Component in context.actor.component_resources:
		if recipe.get_script() == component_script:
			return recipe
	return null
#endregion
