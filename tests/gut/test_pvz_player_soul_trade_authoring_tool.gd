extends GutTest
## Native packed-state authoring preserves player fields and placed composition.

const TOOL: Script = preload("res://addons/pvz_ai_tools/player_soul_trade_authoring_tool.gd")
const PLAYER: PackedScene = preload(
	"res://content/domains/motion/entities/character_body_player.tscn"
)
const CAPABILITY: EntityTrait = preload(
	"res://content/domains/npc/authoring/et_player_soul_trade.tres"
)


#region Detached packed-state fixture
func _root_value(scene: PackedScene, property: StringName) -> Variant:
	var state: SceneState = scene.get_state()
	for index: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == property:
			return state.get_node_property_value(0, index)
	return null


func _with_root_value(
	scene: PackedScene,
	property: StringName,
	replacement: Variant,
) -> PackedScene:
	var original: Variant = _root_value(scene, property)
	var bundled: Dictionary = (scene.get("_bundled") as Dictionary).duplicate()
	var variants: Array = (bundled.variants as Array).duplicate()
	for index: int in variants.size():
		if is_same(variants[index], original):
			variants[index] = replacement
	bundled.variants = variants
	var prepared: PackedScene = PackedScene.new()
	prepared.set("_bundled", bundled)
	return prepared


func _before_capability() -> PackedScene:
	var retained: Array[EntityTrait] = []
	for capability: EntityTrait in _root_value(PLAYER, &"traits") as Array:
		if capability.trait_id != &"player_soul_trade":
			retained.append(capability)
	return _with_root_value(PLAYER, &"traits", retained)
#endregion


#region Native save fidelity and guarded refusal
func test_append_preserves_every_packed_node_property_except_root_traits() -> void:
	var before: PackedScene = _before_capability()
	var result: Dictionary = TOOL.append_trait(before, CAPABILITY)
	assert_false(result.has("error"))
	if result.has("error"):
		return
	var after: PackedScene = result.scene as PackedScene
	var original: SceneState = before.get_state()
	var updated: SceneState = after.get_state()
	assert_eq(updated.get_node_count(), original.get_node_count())
	for node_index: int in original.get_node_count():
		assert_eq(updated.get_node_name(node_index), original.get_node_name(node_index))
		assert_eq(updated.get_node_type(node_index), original.get_node_type(node_index))
		assert_eq(updated.get_node_path(node_index), original.get_node_path(node_index))
		assert_eq(updated.get_node_owner_path(node_index), original.get_node_owner_path(node_index))
		assert_eq(
			updated.get_node_property_count(node_index),
			original.get_node_property_count(node_index),
		)
		for property_index: int in original.get_node_property_count(node_index):
			var property: StringName = original.get_node_property_name(node_index, property_index)
			assert_eq(updated.get_node_property_name(node_index, property_index), property)
			if node_index == 0 and property == &"traits":
				continue
			assert_eq(
				updated.get_node_property_value(node_index, property_index),
				original.get_node_property_value(node_index, property_index),
			)
	var recipes: Array = _root_value(after, &"component_resources") as Array
	assert_eq(recipes.size(), 16)
	assert_true(
		recipes.any(
			func(component: Component) -> bool:
				return component is C_Health,
		)
	)
	assert_true(
		recipes.any(
			func(component: Component) -> bool:
				return component is C_Strength,
		)
	)
	assert_eq((_root_value(after, &"traits") as Array).size(), 3)
	assert_true(TOOL.append_trait(after, CAPABILITY).has("error"))


func test_missing_recipes_wrong_root_or_wrong_capability_refuse_without_mutation() -> void:
	var before: PackedScene = _before_capability()
	var missing: PackedScene = _with_root_value(before, &"component_resources", [])
	assert_true(TOOL.append_trait(missing, CAPABILITY).has("error"))
	assert_true(TOOL.append_trait(PackedScene.new(), CAPABILITY).has("error"))
	var wrong: EntityTrait = EntityTrait.new()
	wrong.trait_id = &"other"
	assert_true(TOOL.append_trait(before, wrong).has("error"))
	assert_eq((_root_value(before, &"traits") as Array).size(), 2)
	assert_eq((_root_value(before, &"component_resources") as Array).size(), 16)


func test_editor_save_refuses_headless_calls_before_writing() -> void:
	var handler: RefCounted = TOOL.new()
	assert_true((handler.call("save", { }, null) as Dictionary).has("error"))
#endregion


#region Native standalone and placed player capability
func test_player_and_main_level_receive_one_fresh_ledger_and_keep_slots() -> void:
	var standalone: Entity = PLAYER.instantiate() as Entity
	var level: Node = (load(GameSessionService.MAIN_LEVEL) as PackedScene).instantiate()
	var placed: Entity = level.get_node("Entityes/Player") as Entity
	var ledgers: Array[C_SoulTrade] = []
	for actor: Entity in [standalone, placed]:
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			actor,
			null,
			"soul_preview",
		)
		var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
		assert_true(plan.valid())
		var count: int = 0
		for component: Component in plan.component_recipes:
			if component is C_SoulTrade:
				count += 1
				ledgers.append(component as C_SoulTrade)
		assert_eq(count, 1)
		assert_not_null(actor.get_node_or_null("BeltSlotLeft"))
		assert_not_null(actor.get_node_or_null("BeltSlotRight"))
	if ledgers.size() == 2:
		assert_ne(ledgers[0], ledgers[1])
		ledgers[0].accepted_count = 1
		assert_eq(ledgers[1].accepted_count, 0)
	standalone.free()
	level.free()
#endregion
