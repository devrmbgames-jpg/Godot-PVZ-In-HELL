@tool
extends EntityTrait
## Compiles standalone customer role data from its existing immutable service policy.
class_name ET_CustomerVisit

## Authored request action; shared immutable between individual customer recipes.
@export var request_action: DEF_CustomerAction
## Authored parcel handoff action; keeps the existing priority and input policy.
@export var handoff_action: DEF_CustomerHandoffAction


#region Pure customer composition
## Requires the selected service Definition and intrinsic physical customer capabilities.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	if not context.actor is E_NpcCharacter:
		issues.append("Customer visit requires an E_NpcCharacter scene root")
	if not context.definitions.get(&"customer_policy") is DEF_Customer:
		issues.append("Customer visit requires its selected service policy")
	if request_action == null or handoff_action == null:
		issues.append("Customer visit requires authored request and handoff actions")
	return issues


## Supplies fresh role state and an isolated action array; Definitions remain immutable.
func recipes_for(_context: EntitySpawnContext) -> Array[Component]:
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [request_action, handoff_action]
	return [C_CustomerAgent.new(), actions]


## Configures existing physical/challenge Components before native publication.
func configuration_for(context: EntitySpawnContext) -> Dictionary[Script, Dictionary]:
	var policy: DEF_Customer = context.definitions.get(&"customer_policy") as DEF_Customer
	if policy == null:
		return { }
	return {
		C_Motion as Script: { &"max_speed": maxf(0.0, policy.move_speed) },
		C_Challenge as Script: { &"definition": policy.challenge },
	}
#endregion
