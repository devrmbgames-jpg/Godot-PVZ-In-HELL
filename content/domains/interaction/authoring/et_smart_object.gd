@tool
extends EntityTrait
## Materializes Smart Object data and native input actions using the common pure compiler.
class_name ET_SmartObject

## Immutable capabilities/slots; tuning stays in the shared definition.
@export var definition: DEF_SmartObject = null


#region Pure schema and recipes
func _init() -> void:
	trait_id = &"smart_object"


## The same diagnostics serve editor snapshots and factory/placed materialization.
func configuration_issues(context: EntitySpawnContext) -> PackedStringArray:
	return SmartObjectRules.issues(definition, context.actor)


## Installs fresh Component recipes; no runtime registry or occupancy is created here.
func recipes_for(_context: EntitySpawnContext) -> Array[Component]:
	var object_data: C_SmartObject = C_SmartObject.new()
	object_data.definition = definition
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	if definition != null:
		for affordance: DEF_SmartAffordance in definition.affordances:
			if affordance == null or affordance.executor == null:
				continue
			var action: DEF_SmartObjectAction = DEF_SmartObjectAction.new()
			action.affordance_id = affordance.affordance_id
			action.action_id = affordance.executor.action_id
			action.slot = affordance.executor.slot
			action.caption = affordance.executor.caption
			action.priority = affordance.executor.priority
			action.continuous = affordance.executor.continuous
			action.allow_interact_fallback = affordance.executor.allow_interact_fallback
			actions.actions.append(action)
	return [object_data, actions]
#endregion
