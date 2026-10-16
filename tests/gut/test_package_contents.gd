extends GutTest
## Проверяет авторское содержимое коробок через реальное вскрытие, физику, инвентарь и snapshot.

const DEF_DELIVERY_MORNING_SUPPLY_PATH: String = (
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)
const BLOOD_ITEM: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_blood_flask.tres"
)
const AXE_ITEM: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_axe.tres"
)
const TOY_ITEM: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)
var _root: Node3D
var _world: World
var _actor: E_RigidBodyCharacter
var _ray: RayCast3D
var _opening_observer: O_PackageOpening


#region Физическое тестовое окружение
## Создаёт физическую опору, игрока и observers вскрытия, содержимого и инвентаря.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	_opening_observer = O_PackageOpening.new()
	_world.add_observer(_opening_observer)
	_world.add_observer(O_PackageContents.new())
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_InventoryEffect.new())
	_world.add_observer(O_InventoryLifecycle.new())
	_world.add_observer(O_GrabLifecycle.new())

	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_LootDrops.new()]
	_root.add_child(session)
	session.owner = _root
	FixturePlacedIdentity.assign(_root, session, &"session")
	_world.add_entity(session, null, false)
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30, 0.2, 30)
	collision.shape = shape
	collision.position.y = -0.1
	floor.add_child(collision)
	_root.add_child(floor)

	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/domains/motion/entities/e_rigid_body_character.gd"))
	_actor = body as Node as E_RigidBodyCharacter
	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = (
		load("res://content/domains/needs/definitions/def_hunger_default.tres") as DEF_HungerPolicy
	)
	var health: C_Health = C_Health.new()
	health.value = 100.0
	health.current = 100.0
	_actor.component_resources = ([
		C_Inventory.new(),
		C_Interactor.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Controller.new(),
		C_Strength.new(),
		health,
		hunger,
	])
	_ray = RayCast3D.new()
	_ray.position = Vector3(0, 1.2, 0)
	_ray.target_position = Vector3(0, 0, -3)
	_ray.collision_mask = 31
	_ray.add_exception(body)
	body.add_child(_ray)
	_actor.interaction_ray_cast = _ray

	var hand: Marker3D = Marker3D.new()
	hand.position = Vector3(0.5, 1, 0)
	body.add_child(hand)
	_actor.right_hand_slot = hand
	_actor.left_hand_slot = hand
	_actor.hold_anchor = hand
	_world.add_entity(_actor)
	_actor.owner = _root
	FixturePlacedIdentity.assign(_root, _actor, &"actor")
	await get_tree().physics_frame
	await get_tree().physics_frame


## Удаляет World с физическими участниками и очищает ECS.world.
func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null


func _package(name: String) -> E_Package:
	var prefab: PackedScene = (
		load("res://content/domains/packages/entities/test_%s.tscn" % name) as PackedScene
	)
	var parcel: E_Package = prefab.instantiate() as E_Package
	(parcel as Node as RigidBody3D).freeze = true
	(parcel as Node as Node3D).position = Vector3(0, 0.5, -1.3)
	_root.add_child(parcel)
	parcel.owner = _root
	FixturePlacedIdentity.assign(_root, parcel, &"parcel")
	EntityCompositionFixture.register(_world, parcel, false)
	return parcel


func _open(parcel: E_Package) -> void:
	_ray.look_at((parcel as Node as Node3D).global_position)
	(_actor.get_component(C_Interactor) as C_Interactor).target = parcel
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(
		PackageOpening.request_open(_actor, parcel).status,
		PackageOpenResult.Status.COMMITTED,
	)
	assert_true((parcel.get_component(C_PackageContents) as C_PackageContents).released)

#endregion


#region Вскрытие, использование и snapshot
## A queued request does not complete a prolonged action before the opening commit.
func test_open_receipt_does_not_report_pending_work_as_success() -> void:
	var parcel: E_Package = _package("bread")
	_ray.look_at((parcel as Node as Node3D).global_position)
	(_actor.get_component(C_Interactor) as C_Interactor).target = parcel
	await get_tree().physics_frame
	await get_tree().physics_frame
	_opening_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL

	var receipt: PackageOpenResult = PackageOpening.request_open(_actor, parcel)
	assert_eq(receipt.status, PackageOpenResult.Status.PENDING)
	assert_false((parcel.get_component(C_PackageContents) as C_PackageContents).released)
	var action: DEF_OpenPackageAction = DEF_OpenPackageAction.new()
	assert_false(action.complete(_actor, parcel, parcel), "Enqueue is not completion")

	_world.flush_command_buffers()
	assert_eq(receipt.status, PackageOpenResult.Status.COMMITTED)
	assert_eq(receipt.reason, &"opened")
	assert_true((parcel.get_component(C_PackageContents) as C_PackageContents).released)
	assert_eq(
		(parcel.get_component(C_PackageState) as C_PackageState).opening,
		C_PackageState.Opening.OPENED,
	)


## Вскрытие обновляет массу переносимого груза, сохраняя живой хват коробки.
func test_opening_held_package_refreshes_empty_carry_mass_without_releasing() -> void:
	var parcel: E_Package = _package("bread")
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.freeze = false
	body.mass = 10.0
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.CARRY
	parcel.add_relationship(Relationship.new(grip, _actor))

	var load_state: C_CarryLoad = _actor.get_component(C_CarryLoad) as C_CarryLoad
	assert_true(load_state.active)
	assert_eq(load_state.mass_kg, 10.0)
	assert_eq(
		PackageOpening.request_open(_actor, parcel).status,
		PackageOpenResult.Status.COMMITTED,
	)
	assert_true(load_state.active)
	assert_eq(load_state.mass_kg, 1.0)
	assert_eq(GrabQueries.held_in_slot(_actor, C_Grabbable.HoldSlot.CARRY), parcel)
	GrabReleaseService.release(_actor, parcel)


## Пять физических порций объединяются в инвентаре; расход и повторное событие не возрождают
## содержимое.
func test_bread_box_produces_five_individual_usable_items_once() -> void:
	var parcel: E_Package = _package("bread")
	await _open(parcel)
	var items: Array[Entity] = _world.query.with_all([C_InventoryItem]).execute().duplicate()
	assert_eq(items.size(), 5)
	for item: Entity in items:
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		assert_eq(state.quantity, 1)
		assert_eq(state.definition.key, &"food")
		assert_false(state.definition.resource_path.is_empty())
		var rigid: RigidBody3D = item as Node as RigidBody3D
		assert_not_null(rigid)
		assert_gt(
			rigid.global_position.y,
			(parcel as Node as Node3D).global_position.y,
			"Contents spill above the parcel",
		)
		assert_gt(rigid.linear_velocity.length(), 0.0, "Real contents have an ejection velocity")
		assert_true(InventoryService.transfer(item, _actor))

	var owned: Array[Entity] = InventoryService.items(_actor)
	assert_eq(owned.size(), 1)
	assert_eq((owned[0].get_component(C_InventoryItem) as C_InventoryItem).quantity, 5)
	(_actor.get_component(C_Hunger) as C_Hunger).value = 80.0
	assert_true(InventoryService.use(_actor, owned[0]))
	assert_eq((_actor.get_component(C_Hunger) as C_Hunger).value, 45.0)
	assert_eq((owned[0].get_component(C_InventoryItem) as C_InventoryItem).quantity, 4)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.OPENED, _actor)
	assert_eq(
		_world.query.with_all([C_InventoryItem]).execute().size(),
		1,
		"Even consumed/merged contents cannot respawn",
	)
	assert_eq(PackageOpening.request_open(_actor, parcel).status, PackageOpenResult.Status.REJECTED)


## Коробка создаёт пять аптечек; успешное лечение расходует выбранный предмет.
func test_med_box_produces_five_medkits_and_consumes_only_successful_healing() -> void:
	await _open(_package("medkits"))
	var items: Array[Entity] = _world.query.with_all([C_InventoryItem]).execute()
	assert_eq(items.size(), 5)
	for item: Entity in items:
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		assert_eq(state.quantity, 1)
		assert_eq(state.definition.key, &"med")

	var health: C_Health = _actor.get_component(C_Health) as C_Health
	health.current = 50.0
	var selected: Entity = items[0]
	assert_true(InventoryService.transfer(selected, _actor))
	assert_true(InventoryService.use(_actor, selected))
	assert_eq(health.current, 85.0)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 4)


## Snapshot восстанавливает пустую оболочку и существующее содержимое без повторного выпадения.
func test_released_contents_and_inventory_state_restore_without_duplication() -> void:
	var parcel: E_Package = _package("bread")
	await _open(parcel)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_true((parcel.get_component(C_PackageContents) as C_PackageContents).released)
	assert_eq((parcel as Node as RigidBody3D).mass, parcel.package_definition.empty_mass_kg)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 5)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.OPENED, _actor)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 5)
	NightResetService.reset()
	assert_true((parcel.get_component(C_PackageContents) as C_PackageContents).released)

#endregion


#region Авторский ассортимент и опасности
## Catalog payload replaces old bottle effects; reopening never duplicates it.
func test_selected_catalog_weapon_releases_real_contents_without_legacy_bottle_hazards() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ToxicAreaSetup.new())
	_world.add_observer(O_PackageHazard.new())
	_world.add_observer(O_PackageDestruction.new())
	_world.add_observer(O_PackageDestroyedHazard.new())
	_world.add_system(S_LiquidTilt.new())
	var selected: DEF_InventoryItem = AXE_ITEM
	var parcel: E_Package = _catalog_package(_supply_definition(&"bottles"), selected)
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	(parcel as Node as Node3D).rotation.z = PI / 2.0
	_world.process(30.0)
	assert_false((parcel.get_component(C_PackageState) as C_PackageState).leaking)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DAMAGED, _actor)
	assert_eq(_world.query.with_all([C_ToxicArea]).execute().size(), 0)
	var items: Array[Entity] = PackageContentsService.release(parcel, _actor)
	assert_eq(items.size(), 1)
	if items.is_empty():
		return
	assert_eq(items[0].scene_file_path, selected.world_pickup_scene)
	assert_same((items[0].get_component(C_InventoryItem) as C_InventoryItem).definition, selected)
	assert_true(items[0].has_component(C_MeleeWeapon))
	assert_true(contents.released)
	assert_true(PackageContentsService.release(parcel, _actor).is_empty())
	assert_eq(_world.query.with_all([C_ToxicArea]).execute().size(), 0)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DESTROYED, _actor)
	assert_eq(_world.query.with_all([C_ToxicArea]).execute().size(), 0)


## Solid catalog cargo does not compile a liquid recipe or inherit legacy bottle hazards.
func test_catalog_artifact_has_no_liquid_capability_or_legacy_rupture() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_PackageHazard.new())
	_world.add_observer(O_PackageDestruction.new())
	_world.add_observer(O_PackageDestroyedHazard.new())
	_world.add_system(S_LiquidTilt.new())
	var artifact: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_holy_artifact.tres"
	) as DEF_InventoryItem
	var parcel: E_Package = _catalog_package(_supply_definition(&"bottles"), artifact)
	assert_false(parcel.has_component(C_LiquidTilt))
	assert_false(PackageContentsService.is_liquid(parcel))
	(parcel as Node as Node3D).rotation.z = PI / 2.0
	_world.process(30.0)
	assert_false((parcel.get_component(C_PackageState) as C_PackageState).leaking)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DAMAGED, _actor)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DESTROYED, _actor)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 0)


## A liquid ordered in a formerly dry shell leaks once using its actual native effect.
func test_catalog_liquid_leaks_with_its_native_effect_under_dry_legacy_definition() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_PackageHazard.new())
	_world.add_system(S_LiquidTilt.new())
	var blood: DEF_InventoryItem = BLOOD_ITEM
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), blood)
	var tilt: C_LiquidTilt = parcel.get_component(C_LiquidTilt) as C_LiquidTilt
	assert_not_null(tilt)
	assert_true(PackageContentsService.is_liquid(parcel))
	assert_eq(tilt.duration_seconds, blood.cargo_profile.liquid_tilt_seconds)
	(parcel as Node as Node3D).rotation.z = PI / 2.0
	_world.process(tilt.duration_seconds + 0.1)
	assert_true((parcel.get_component(C_PackageState) as C_PackageState).leaking)
	var effects: Array[Entity] = _world.query.with_all([C_Hazard]).execute()
	assert_eq(effects.size(), 1)
	assert_eq(effects[0].scene_file_path, blood.cargo_profile.rupture_hazard.resource_path)
	_world.process(30.0)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 1)


#region Actual payload fire destruction
func _legacy_fire_definition() -> DEF_Package:
	var definition: DEF_Package = _supply_definition(&"bottles").duplicate(true) as DEF_Package
	definition.unpack_scene = load(BLOOD_ITEM.world_pickup_scene) as PackedScene
	return definition


func _install_fire_destruction() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_PackageDamage.new())
	_world.add_observer(O_PackageDestruction.new())
	_world.add_observer(O_PackageDestroyedHazard.new())


func _fire_damage(parcel: E_Package, amount: float) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.target = parcel
	request.source = _actor
	request.instigator = _actor
	request.amount = amount
	request.damage_type = DamageRequest.Type.FIRE
	assert_true(DamageRequestService.submit(request))


func test_remaining_payload_reads_native_legacy_item_without_creating_nodes() -> void:
	var contents: C_PackageContents = C_PackageContents.new()
	var definition: DEF_Package = _legacy_fire_definition()
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var item: DEF_InventoryItem = PackagePayloadRules.remaining_item(definition, contents)
	assert_same(item, BLOOD_ITEM)
	assert_eq(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), node_count)
	assert_null(PackagePayloadRules.remaining_item(_supply_definition(&"bottles"), contents))
	contents.selected_item = AXE_ITEM
	contents.quantity = 2
	assert_same(PackagePayloadRules.remaining_item(definition, contents), contents.selected_item)
	contents.quantity = 0
	assert_null(PackagePayloadRules.remaining_item(definition, contents))
	contents.quantity = 2
	contents.released = true
	assert_null(PackagePayloadRules.remaining_item(definition, contents))


func test_lethal_fire_consumes_all_catalog_units_before_debris_without_intact_loot() -> void:
	_install_fire_destruction()
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), TOY_ITEM, 8)
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	_fire_damage(parcel, 10000.0)
	assert_true(contents.released)
	assert_eq(contents.quantity, 8, "Committed arrival composition stays immutable")
	assert_eq(_world.query.with_all([C_Package]).execute().size(), 0)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 0)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 0)
	var queue_owner: Entity = _world.query.with_all([C_LootDrops]).execute_one()
	assert_true((queue_owner.get_component(C_LootDrops) as C_LootDrops).pending.is_empty())


func test_fire_consumption_is_one_shot_and_refreshes_the_actual_held_mass() -> void:
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), TOY_ITEM, 8)
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.freeze = false
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	var carry: C_CarryLoad = _actor.get_component(C_CarryLoad) as C_CarryLoad
	assert_true(carry.active)
	var full_mass: float = body.mass
	assert_true(PackageContentsService.consume_fire_remainder(parcel))
	assert_false(PackageContentsService.consume_fire_remainder(parcel))
	assert_true(PackageContentsService.is_empty(parcel))
	assert_lt(body.mass, full_mass)
	assert_almost_eq(body.mass, PackageContentsService.empty_mass_kg(parcel), 0.0001)
	assert_almost_eq(carry.mass_kg, body.mass, 0.0001)
	assert_same(GrabQueries.held_object(_actor), parcel)
	assert_true(PackageContentsService.release(parcel, _actor).is_empty())


func test_nonlethal_fire_keeps_the_payload_inside_the_box() -> void:
	_install_fire_destruction()
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), TOY_ITEM)
	_fire_damage(parcel, 1.0)
	assert_false(PackageContentsService.is_empty(parcel))


func test_immune_catalog_item_is_not_marked_consumed_by_fire() -> void:
	_install_fire_destruction()
	var parcel: E_Package = _catalog_package(_supply_definition(&"bottles"), AXE_ITEM)
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	_fire_damage(parcel, 10000.0)
	assert_false(contents.released)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 0)


func test_newly_burned_legacy_contents_emit_their_native_destruction_effect_once() -> void:
	_install_fire_destruction()
	var parcel: E_Package = _catalog_package(_legacy_fire_definition())
	var definition: DEF_Package = parcel.package_definition
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	_fire_damage(parcel, 10000.0)
	assert_true(contents.released)
	var effects: Array[Entity] = _world.query.with_all([C_Hazard]).execute()
	assert_eq(effects.size(), 1)
	if effects.size() == 1:
		assert_eq(effects[0].scene_file_path, definition.hazard_on_destroyed.resource_path)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 0)


func test_fire_destruction_of_released_legacy_shell_does_not_repeat_the_payload_effect() -> void:
	_install_fire_destruction()
	var parcel: E_Package = _catalog_package(_legacy_fire_definition())
	var items: Array[Entity] = PackageContentsService.release(parcel, _actor)
	assert_false(items.is_empty())
	var effects_before: int = _world.query.with_all([C_Hazard]).execute().size()
	_fire_damage(parcel, 10000.0)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), effects_before)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), items.size())


func test_catalog_fire_rupture_keeps_actual_effect_without_legacy_or_intact_payload() -> void:
	_install_fire_destruction()
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), BLOOD_ITEM)
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	_fire_damage(parcel, 10000.0)
	assert_true(contents.released)
	var effects: Array[Entity] = _world.query.with_all([C_Hazard]).execute()
	assert_eq(effects.size(), 1)
	if effects.size() == 1:
		assert_eq(effects[0].scene_file_path, BLOOD_ITEM.cargo_profile.rupture_hazard.resource_path)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 0)
#endregion


## Destruction captures the payload effect before replacement and never uses the old book recipe.
func test_catalog_acid_destruction_uses_actual_payload_effect_on_debris() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_PackageDestruction.new())
	_world.add_observer(O_PackageDestroyedHazard.new())
	var acid: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_acid_barrel.tres"
	) as DEF_InventoryItem
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), acid)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DESTROYED, _actor)
	var effects: Array[Entity] = _world.query.with_all([C_Hazard]).execute()
	assert_eq(effects.size(), 1)
	assert_eq(effects[0].scene_file_path, acid.cargo_profile.rupture_hazard.resource_path)
	assert_eq(_world.query.with_all([C_Package]).execute().size(), 0)


## The same native catalog payload cannot rupture twice across damage and destruction.
func test_one_catalog_payload_cannot_rupture_again_on_destruction_after_damage() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_PackageHazard.new())
	_world.add_observer(O_PackageDamage.new())
	_world.add_observer(O_PackageDestruction.new())
	_world.add_observer(O_PackageDestroyedHazard.new())
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), BLOOD_ITEM)
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	var request: DamageRequest = DamageRequest.new()
	request.target = parcel
	request.source = _actor
	request.instigator = _actor
	request.amount = 50.0
	assert_true(DamageRequestService.submit(request))
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 1)
	assert_true(contents.released, "The native rupture consumes this payload before callbacks")
	assert_almost_eq(
		(parcel as Node as RigidBody3D).mass, PackageContentsService.empty_mass_kg(parcel), 0.0001,
	)
	request = DamageRequest.new()
	request.target = parcel
	request.source = _actor
	request.instigator = _actor
	request.amount = 100.0
	assert_true(DamageRequestService.submit(request))
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 1)


## A ruptured liquid cannot later materialize an intact item with an unfired native emitter.
func test_catalog_leak_then_open_cannot_release_a_second_payload_effect() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_HazardEmitter.new())
	_world.add_observer(O_PackageHazard.new())
	_world.add_system(S_LiquidTilt.new())
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), BLOOD_ITEM)
	(parcel as Node as Node3D).rotation.z = PI / 2.0
	var tilt: C_LiquidTilt = parcel.get_component(C_LiquidTilt) as C_LiquidTilt
	_world.process(tilt.duration_seconds + 0.1)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 1)
	assert_true((parcel.get_component(C_PackageContents) as C_PackageContents).released)
	var items: Array[Entity] = PackageContentsService.release(parcel, _actor)
	assert_true(items.is_empty(), "Spent contents never become a fresh native flask")
	if not items.is_empty():
		var request: DamageRequest = DamageRequest.new()
		request.target = items[0]
		request.source = _actor
		request.instigator = _actor
		request.amount = 100.0
		assert_true(DamageRequestService.submit(request))
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 1)


## Normal opening releases an intact catalog item; its own damage produces the effect later.
func test_catalog_liquid_opening_does_not_rupture_its_intact_native_item() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_HazardEmitter.new())
	_world.add_observer(O_PackageHazard.new())
	var blood: DEF_InventoryItem = BLOOD_ITEM
	var parcel: E_Package = _catalog_package(_supply_definition(&"bottles"), blood)
	var items: Array[Entity] = PackageContentsService.release(parcel, _actor)
	assert_eq(items.size(), 1)
	assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 0)
	assert_false((items[0].get_component(C_HazardEmitter) as C_HazardEmitter).fired)
	var request: DamageRequest = DamageRequest.new()
	request.target = items[0]
	request.source = _actor
	request.instigator = _actor
	request.amount = 100.0
	assert_true(DamageRequestService.submit(request))
	var effects: Array[Entity] = _world.query.with_all([C_Hazard]).execute()
	assert_eq(effects.size(), 1)
	assert_eq(effects[0].scene_file_path, blood.cargo_profile.rupture_hazard.resource_path)


## Real bulk emits exactly the committed unit count, even when the old recipe specified one.
func test_catalog_bulk_releases_committed_quantity_and_keeps_empty_packing_mass() -> void:
	var toy: DEF_InventoryItem = TOY_ITEM
	var parcel: E_Package = _catalog_package(_supply_definition(&"books"), toy, 8)
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	assert_eq(contents.quantity, 8)
	assert_eq(contents.packing_profile.key, &"large")
	assert_almost_eq((parcel as Node as RigidBody3D).mass, 6.0, 0.0001)
	var items: Array[Entity] = PackageContentsService.release(parcel, _actor)
	var queue: C_LootDrops = LootDropService.current()
	assert_eq(items.size() + queue.pending.size(), 8)
	for item: Entity in items:
		assert_same((item.get_component(C_InventoryItem) as C_InventoryItem).definition, toy)
	assert_almost_eq((parcel as Node as RigidBody3D).mass, 2.0, 0.0001)
	assert_true(PackageContentsService.release(parcel, _actor).is_empty())
	assert_eq(items.size() + queue.pending.size(), 8, "Reopening cannot duplicate payload")


func _catalog_package(
	definition: DEF_Package,
	selected: DEF_InventoryItem = null,
	quantity: int = 1,
) -> E_Package:
	var supply: DEF_Delivery = load(DEF_DELIVERY_MORNING_SUPPLY_PATH) as DEF_Delivery
	var shipment: PackageShipmentPlan = null
	if selected != null:
		shipment = PackageShipmentRules.for_quantity(
			selected, quantity, supply.packing_profiles, 1, "fixture/contents", 1,
		)
	var path: String = shipment.scene_path() if shipment != null else definition.scene_variants[0]
	var scene: PackedScene = load(path) as PackedScene
	var parcel: E_Package = scene.instantiate() as E_Package
	parcel.package_definition = definition
	if shipment != null:
		(parcel as Node as RigidBody3D).mass = shipment.gross_mass_kg()
	(parcel as Node as RigidBody3D).freeze = true
	(parcel as Node as Node3D).position = Vector3(5, 1, 5)
	if selected == null:
		EntityCompositionFixture.register(_world, parcel)
	else:
		parcel.package_id = GECSIO.uuid()
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			parcel, _world, GECSIO.uuid()
		)
		context.initial_fields[C_PackageContents as Script] = shipment.contents_fields()
		var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
		var issues: PackedStringArray = []
		for issue: EntityBuildPlan.Issue in plan.issues:
			issues.append(issue.message)
		assert_true(plan.valid(), "; ".join(issues))
		var registered: bool = EntityCompositionService.register_plan(context, plan)
		assert_true(registered)
		if not registered:
			parcel.free()
			return null
	(parcel.get_component(C_PackageState) as C_PackageState).opening = C_PackageState.Opening.OPENED
	return parcel


func _supply_definition(key: StringName) -> DEF_Package:
	var supply: DEF_Delivery = (load(DEF_DELIVERY_MORNING_SUPPLY_PATH) as DEF_Delivery)
	for definition: DEF_Package in supply.packages:
		if definition.key == key:
			return definition
	return null


## Каждый авторский тип выпускает реальные тела однократно и оставляет лёгкую оболочку без протечки.
func test_every_supply_type_has_real_one_shot_contents_and_leaves_empty_light_shell() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ToxicAreaSetup.new())
	var supply: DEF_Delivery = (load(DEF_DELIVERY_MORNING_SUPPLY_PATH) as DEF_Delivery)
	for definition: DEF_Package in supply.packages:
		assert_not_null(definition.unpack_scene, String(definition.key))
		var parcel: E_Package = _catalog_package(definition)
		(parcel.get_component(C_PackageState) as C_PackageState).leaking = true
		var contents: Array[Entity] = PackageContentsService.release(parcel, _actor)
		assert_eq(contents.size(), definition.content_quantity, String(definition.key))
		for item: Entity in contents:
			assert_true((item as Node) is RigidBody3D)
			assert_false((item as Node as RigidBody3D).freeze)
		assert_true(PackageContentsService.is_empty(parcel))
		assert_false((parcel.get_component(C_PackageState) as C_PackageState).leaking)
		assert_eq((parcel as Node as RigidBody3D).mass, definition.empty_mass_kg)
		assert_true(PackageContentsService.release(parcel).is_empty())
		# Каждый prefab проверяется в свободном месте; занятая партия проверяется отдельно.
		for item: Entity in contents:
			_world.remove_entity(item)
		_world.remove_entity(parcel)
		await get_tree().physics_frame
		await get_tree().physics_frame


## Токсичная зона следует за вынутой бутылкой; пустая коробка не создаёт новые опасности.
func test_toxic_effect_follows_extracted_bottle_and_empty_shell_has_no_hazards_or_leaks() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ToxicAreaSetup.new())
	_world.add_observer(O_PackageHazard.new())
	_world.add_observer(O_PackageDestruction.new())
	_world.add_observer(O_PackageDestroyedHazard.new())
	_world.add_system(S_LiquidTilt.new())
	var parcel: E_Package = _catalog_package(_supply_definition(&"bottles"))
	var tilt: C_LiquidTilt = C_LiquidTilt.new()
	tilt.duration_seconds = 0.0
	parcel.add_component(tilt)

	var contents: Array[Entity] = PackageContentsService.release(parcel, _actor)
	var effect: Entity = _world.query.with_all([C_ToxicArea]).execute_one()
	assert_not_null(effect)
	assert_eq(HazardFollowService.binding(effect).target, contents[0])
	(parcel as Node as Node3D).rotation.z = PI / 2.0
	_world.process(30.0)
	assert_false((parcel.get_component(C_PackageState) as C_PackageState).leaking)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DAMAGED, _actor)
	var toxin_count_0: int = _world.query.with_all([C_ToxicArea]).execute().size()
	assert_eq(toxin_count_0, 1, "Empty shell cannot emit damage toxin")
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DESTROYED, _actor)
	var toxin_count_1: int = _world.query.with_all([C_ToxicArea]).execute().size()
	assert_eq(toxin_count_1, 1, "Empty debris cannot emit toxin")
	assert_eq(HazardFollowService.binding(effect).target, contents[0])


## Вынутый источник питания взрывается по урону один раз, а пустая упаковка не взрывается.
func test_extracted_power_cell_can_explode_but_its_empty_package_cannot() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ExplosionSetup.new())
	_world.add_observer(O_HazardEmitter.new())
	_world.add_observer(O_PackageDestruction.new())
	_world.add_observer(O_PackageDestroyedHazard.new())
	var parcel: E_Package = _catalog_package(_supply_definition(&"power_cells"))
	var contents: Array[Entity] = PackageContentsService.release(parcel, _actor)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.DESTROYED, _actor)
	assert_eq(_world.query.with_all([C_Explosion]).execute().size(), 0)

	var request: DamageRequest = DamageRequest.new()
	request.target = contents[0]
	request.source = _actor
	request.instigator = _actor
	request.amount = 100.0
	assert_true(DamageRequestService.submit(request))
	assert_eq(_world.query.with_all([C_Explosion]).execute().size(), 1)
	assert_true((contents[0].get_component(C_HazardEmitter) as C_HazardEmitter).fired)
	assert_false(HazardEmitter.activate(contents[0], _actor))

#endregion


#region Физическое хранение и оборудование
## Инвентарь выключает физику хранимого предмета; выброс создаёт активное физическое тело.
func test_inventory_freezes_real_pickup_and_drop_spawns_live_rigid_body() -> void:
	var parcel: E_Package = _package("bread")
	await _open(parcel)
	var item: Entity = _world.query.with_all([C_InventoryItem]).execute_one()
	var body: RigidBody3D = item as Node as RigidBody3D
	assert_true(InventoryService.transfer(item, _actor))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(body.freeze)
	assert_eq(body.collision_layer, 0)

	var before: Array[Entity] = _world.query.with_all([C_InventoryItem]).execute().duplicate()
	assert_true(InventoryDropService.drop(_actor, item))
	var dropped: RigidBody3D = null
	for candidate: Entity in _world.query.with_all([C_InventoryItem]).execute():
		if candidate not in before:
			dropped = candidate as Node as RigidBody3D
	assert_not_null(dropped)
	if dropped == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(dropped.freeze)
	assert_eq(dropped.collision_layer, 8)


## Авторская опасность вскрытия использует штатный emitter и не повторяется от дублирующего события.
func test_authored_opening_hazard_uses_existing_emitter_and_deduplicates_hook() -> void:
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ExplosionSetup.new())
	_world.add_observer(O_PackageHazard.new())
	var prefab: PackedScene = (
		load("res://content/domains/packages/entities/test_bread.tscn") as PackedScene
	)
	var parcel: E_Package = prefab.instantiate() as E_Package
	parcel.package_definition = parcel.package_definition.duplicate(true) as DEF_Package
	parcel.package_definition.hazard_on_opened = (
		load("res://content/domains/hazards/entities/explosion.tscn") as PackedScene
	)
	(parcel as Node as RigidBody3D).freeze = true
	(parcel as Node as Node3D).position = Vector3(0, 0.5, -1.3)
	EntityCompositionFixture.register(_world, parcel)
	await _open(parcel)
	assert_eq(_world.query.with_all([C_Explosion]).execute().size(), 1)
	PackageLifecycle.publish(parcel, PackageLifecycleEvent.Kind.OPENED, _actor)
	assert_eq(_world.query.with_all([C_Explosion]).execute().size(), 1)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 5)


## Выпавшая полка имеет реальную опору и крепится молотком; фиксация сохраняется в snapshot.
func test_small_shelf_has_two_open_sections_and_can_be_fastened_with_actual_hammer() -> void:
	await _open(_package("small_shelf"))
	var shelf: Entity = _world.query.with_all([C_Anchorable]).execute_one()
	assert_not_null(shelf)
	var body: RigidBody3D = shelf as Node as RigidBody3D
	assert_eq(body.mass, 18.0)
	assert_eq(
		shelf
		.get_children()
		.filter(
			func(child: Node) -> bool:
				return child is CollisionShape3D,
		)
		.size(),
		6,
	)
	var bottom: CollisionShape3D = shelf.get_node("BottomCollision") as CollisionShape3D
	assert_eq((bottom.shape as BoxShape3D).size, Vector3(1.5, 0.08, 1.5))
	assert_almost_eq(
		body.global_position.y,
		1.53,
		0.01,
		"Shelf is placed with its real bottom on the floor",
	)

	var hammer: Entity = (
		(load("res://content/domains/combat/entities/hammer.tscn") as PackedScene).instantiate()
		as Entity
	)
	EntityCompositionFixture.register(_world, hammer)
	(hammer as Node as RigidBody3D).gravity_scale = 0.0
	(hammer as Node as Node3D).global_position = Vector3(-2, 1, 0)
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	hammer.add_relationship(Relationship.new(grip, _actor))
	var config: C_Anchorable = shelf.get_component(C_Anchorable) as C_Anchorable
	for frame: int in 180:
		await get_tree().physics_frame
		InteractionPhysicsFixture.anchor(shelf, 1.0 / 60.0)
		if config.stable_seconds >= config.minimum_rest_seconds:
			break

	_ray.look_at(body.global_position)
	(_actor.get_component(C_Interactor) as C_Interactor).target = shelf
	assert_not_null(GrabQueries.held_relationship(hammer))
	assert_true(GrabReachQueries.within_pickup_reach(_actor, shelf))
	assert_true(AnchoringService.anchor(_actor, hammer, shelf))
	assert_true(body.freeze)
	assert_true(shelf.has_component(C_PlayerAnchored))
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_true(shelf.has_component(C_PlayerAnchored))
	assert_true(body.freeze)

#endregion


#region Rejected death-drop construction
## Failed physical construction keeps the owned stack and releases every detached Node.
func test_death_drop_rejects_wrong_root_and_missing_stack_without_losing_inventory() -> void:
	var definition: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_food.tres"
	).duplicate() as DEF_InventoryItem
	assert_true(InventoryService.grant(_actor, definition, 3))
	var source: Entity = InventoryService.items(_actor)[0]
	var stack: C_InventoryItem = source.get_component(C_InventoryItem) as C_InventoryItem
	var entities_before: int = _world.entities.size()
	var children_before: int = _root.get_child_count()

	for scene_path: String in [
		"res://tests/fixtures/invalid_furniture.tscn",
		"res://tests/fixtures/invalid_delivery_pickup.tscn",
		"res://tests/fixtures/missing_pickup_stack.tscn",
		"res://tests/fixtures/" + "nonexistent_pickup.tscn",
	]:
		definition.world_pickup_scene = scene_path
		InventoryDropService.release_on_death(_actor)
		assert_same(InventoryService.owner_for(source), _actor)
		assert_eq(InventoryService.items(_actor), [source])
		assert_eq(stack.quantity, 3)
		assert_false(stack.transfer_in_progress)
		assert_eq(_world.entities.size(), entities_before)
		assert_eq(_root.get_child_count(), children_before)
		assert_no_new_orphans(scene_path)
#endregion


#region Accepted death-drop publication
## Native observers see the complete replacement stack before the owned source is removed.
func test_death_drop_publishes_complete_stack_once_before_removing_source() -> void:
	var definition: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_med.tres"
	) as DEF_InventoryItem
	assert_true(InventoryService.grant(_actor, definition, 3))
	var source: Entity = InventoryService.items(_actor)[0]
	var publications: Array[Entity] = []
	_world.entity_added.connect(
		func(pickup: Entity) -> void:
			publications.append(pickup)
			var stack: C_InventoryItem = pickup.get_component(C_InventoryItem) as C_InventoryItem
			assert_not_null(stack)
			assert_same(stack.definition, definition)
			assert_eq(stack.quantity, 3)
			assert_same(InventoryService.owner_for(source), _actor)
			assert_null(InventoryService.owner_for(pickup)),
	)

	InventoryDropService.release_on_death(_actor)
	assert_eq(publications.size(), 1)
	assert_true(InventoryService.items(_actor).is_empty())
	var physical_items: Array[Entity] = _world.query.with_all([C_InventoryItem]).execute()
	assert_eq(physical_items, publications)
	assert_true((physical_items[0] as Node) is RigidBody3D)
	assert_no_new_orphans()
#endregion
