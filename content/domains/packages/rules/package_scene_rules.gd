extends RefCounted
## Chooses a package variant from canonical paths, independent of authored container ordering.
class_name PackageSceneRules

#region Physical variant selection
## Previews a stable package/day variant; rejected placement and retries consume no sequence.
static func variant_for(definition: DEF_Package, package_id: String,
		day_index: int, world_seed: int) -> String:
	assert(not definition.scene_variants.is_empty())
	var paths: Array[String] = definition.scene_variants.duplicate()
	paths.sort()
	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		world_seed, package_id, day_index, "package/scene",
	)
	return paths[random.randi_range(0, paths.size() - 1)]
#endregion
