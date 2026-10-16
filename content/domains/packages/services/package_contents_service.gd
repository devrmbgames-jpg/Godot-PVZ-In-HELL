extends RefCounted
## Однократно фиксирует содержимое коробки; свободная позиция и остаток принадлежат очереди лута.
class_name PackageContentsService

const CONTENTS_COLUMNS: int = 3
const CONTENTS_SPACING: float = 0.65
const SPILL_CLEARANCE: float = 0.15
const SPILL_ITEMS_PER_RING: int = 6


#region Состояние и извлечение
## released — единственный признак пустой оболочки, в том числе с ожидающим остатком после загрузки.
static func is_empty(package: Entity) -> bool:
	if not is_instance_valid(package):
		return false

	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	return contents != null and contents.released


## Identifies the committed catalog payload, whose own profile replaces legacy contents facts.
static func has_catalog_order(package: Entity) -> bool:
	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	return contents != null and contents.selected_item != null


## Full payload plus shell mass in kilograms, read from the committed composition.
static func full_mass_kg(package: Entity) -> float:
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	if contents == null or contents.selected_item == null:
		return identity.definition.mass_kg
	return (
		contents.packing_profile.empty_mass_kg
		+ contents.selected_item.cargo_profile.unit_mass_kg * contents.quantity
	)


## Shell-only mass in kilograms; consuming contents never restores an unrelated legacy shell mass.
static func empty_mass_kg(package: Entity) -> float:
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	if contents == null or contents.selected_item == null:
		return identity.definition.empty_mass_kg
	return contents.packing_profile.empty_mass_kg


## Requires a package identity; reads the payload phase without treating all catalog items as solid.
static func is_liquid(package: Entity) -> bool:
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	return PackageLiquidRules.is_liquid(
		identity.definition, contents.selected_item if contents != null else null
	)


## Consumes the actual ruptured payload once before callbacks; returns its captured native effect.
## Existing released is the durable empty/consumed authority, also blocking later intact extraction.
static func consume_catalog_rupture(package: Entity) -> PackedScene:
	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	if contents == null or contents.released or contents.selected_item == null:
		return null
	var scene: PackedScene = contents.selected_item.cargo_profile.rupture_hazard
	if scene == null:
		return null
	var body: RigidBody3D = package as Node as RigidBody3D
	contents.released = true
	body.mass = empty_mass_kg(package)
	GrabService.refresh_carry_mass(package)
	return scene


## Rebuilds derived liquid capability after validated passive overlay, before World readiness.
## Saved leak facts remain untouched; transient timers never replay across restore.
static func restore_liquid_capability(package: Entity) -> void:
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	var recipe: C_LiquidTilt = PackageLiquidRules.recipe_for(
		identity.definition, contents.selected_item if contents != null else null
	)
	var tilt: C_LiquidTilt = package.get_component(C_LiquidTilt) as C_LiquidTilt
	if recipe == null:
		if tilt != null:
			package.remove_component(C_LiquidTilt)
		return
	if tilt == null:
		package.add_component(recipe)
		return
	tilt.maximum_angle_degrees = recipe.maximum_angle_degrees
	tilt.duration_seconds = recipe.duration_seconds
	tilt.damage_amount = recipe.damage_amount
	tilt.unsafe_seconds = 0.0
	tilt.triggered = false


## Фиксирует состав открытой целой коробки один раз; возвращает только безопасно размещённые тела.
## captured_actor_id preserves committed attribution when the optional live initiator is
## unavailable.
## Пустой массив означает отказ либо ни одного размещённого тела; committed остаток живёт в очереди.
## released/масса фиксируются до enqueue, поэтому успешное извлечение не требует свободных позиций.
static func release(
	package: Entity,
	actor: Entity = null,
	captured_actor_id: String = "",
) -> Array[Entity]:
	if not EntityAvailability.contains(package, ECS.world):
		return []

	var state: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	var body: RigidBody3D = package as Node as RigidBody3D
	if (
		state == null or state.released or identity == null
		or identity.definition == null or body == null
	):
		return []
	if (
		condition == null or condition.opening != C_PackageState.Opening.OPENED
		or condition.damage == C_PackageState.Damage.DESTROYED
	):
		return []

	var definition: DEF_Package = identity.definition
	var content_scene: PackedScene = definition.unpack_scene
	var quantity: int = definition.content_quantity
	if state.selected_item != null:
		if not PackageOrderRules.is_orderable(state.selected_item):
			return []
		content_scene = load(state.selected_item.world_pickup_scene) as PackedScene
		quantity = state.quantity
	if (
		content_scene == null or quantity < 1 or quantity > DEF_Package.MAX_CONTENT_QUANTITY
	):
		return []
	var queue: C_LootDrops = LootDropService.current()
	if queue == null:
		return []
	var scenes: Array[PackedScene] = []
	for index: int in quantity:
		scenes.append(content_scene)
	var items: Array[Entity] = LootDropService.prepare(scenes)
	if items.is_empty():
		return []

	var template: PendingLootDrop = PendingLootDrop.new()
	template.anchor = body.global_position
	template.source_id = package.id
	template.actor_id = (
		captured_actor_id
		if not captured_actor_id.is_empty()
		else (actor.id if is_instance_valid(actor) else "")
	)
	template.package_id = identity.package_id
	template.airborne = definition.spill_contents
	template.activate_hazard = state.selected_item == null and definition.activate_contents_hazard
	template.opening_hazard_path = (
		definition.hazard_on_opened.resource_path
		if state.selected_item == null and definition.hazard_on_opened != null
		else ""
	)
	var origins: PackedVector3Array = _origins(body, items, definition)

	# Guard и состав фиксируются до регистрации тел; повтор события не создаёт вторую партию.
	state.released = true
	condition.leaking = false
	body.mass = empty_mass_kg(package)
	GrabService.refresh_carry_mass(package)
	return (
		LootDropService.enqueue(
			queue,
			"package/" + identity.package_id + "/contents",
			items,
			template,
			origins,
		)
	)


static func _origins(
	body: RigidBody3D,
	items: Array[Entity],
	definition: DEF_Package,
) -> PackedVector3Array:
	var origins: PackedVector3Array = PackedVector3Array()
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	var top: float = (
		solver.bounds_at(body.global_transform).end.y
		if solver.prepare(body)
		else body.global_position.y
	)
	var first: RigidBody3D = items[0] as Node as RigidBody3D
	var bottom: float = 0.0
	if solver.prepare(first):
		bottom = solver.bounds_at(Transform3D(first.transform.basis, Vector3.ZERO)).position.y
	for index: int in items.size():
		var position: Vector3 = body.global_position + definition.unpack_offset
		var ring: int = index / SPILL_ITEMS_PER_RING
		var ring_size: int = mini(SPILL_ITEMS_PER_RING, items.size() - ring * SPILL_ITEMS_PER_RING)
		var angle: float = TAU * float(index % SPILL_ITEMS_PER_RING) / ring_size
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		if definition.spill_contents:
			position.y = top - bottom + SPILL_CLEARANCE
			position += direction * CONTENTS_SPACING * (ring + 1)
			var spill_body: RigidBody3D = items[index] as Node as RigidBody3D
			spill_body.linear_velocity = (direction + Vector3.UP) * definition.spill_speed
		else:
			position += (
				Vector3(index % CONTENTS_COLUMNS, 0.0, index / CONTENTS_COLUMNS) * CONTENTS_SPACING
			)
		origins.append(position)
	return origins
#endregion
