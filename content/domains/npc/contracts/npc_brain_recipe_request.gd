extends RefCounted
## Synchronous immutable tree recipe selection; native NPC remains the sole BTPlayer writer.
class_name NpcBrainRecipeRequest

## Native default or a higher-owned authored composition; no runtime tree instance is retained.
var tree: BehaviorTree

#region Recipe request construction
## Starts with the generic native recipe, which higher composition may replace explicitly.
func _init(native_tree: BehaviorTree) -> void:
	tree = native_tree
#endregion
