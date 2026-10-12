extends RefCounted
## Explicit fire inspection/ignition; the order owns the committed roll, Hazards execute damage.
class_name CustomerFireOpeningService

const BLAST_SCENE: String = "res://content/domains/hazards/entities/explosion.tscn"


#region Immutable receiver capability
## Optional capability on the current district person; standalone customers retain their policy.
static func rule_for(customer: Entity) -> DEF_NpcFireAura:
	var identity: C_NpcIdentity = customer.get_component(C_NpcIdentity) as C_NpcIdentity
	if identity == null:
		return null
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	return person.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) as DEF_NpcFireAura


## Stable per-visit choice to inspect at the physical handoff, without reserving a booth.
static func opens_at_handoff(customer: Entity, visit: CustomerVisit) -> bool:
	var rule: DEF_NpcFireAura = rule_for(customer)
	if rule == null:
		return false
	var probability: float = rule.immediate_unpack_probability
	return CustomerInspectionRules.roll(visit, "fire_immediate") < probability
#endregion


#region Committed physical opening
## Consumes a placed physical item only for the receiver who actually opened this parcel.
static func ignite_contents(
	customer: E_NpcCharacter,
	package: Entity,
	item: Entity,
	opening_actor_id: String,
) -> void:
	var world: World = ECS.world
	# Item binding emits facts synchronously; callers may have been retired by another subscriber.
	if (
		not EntityAvailability.contains(customer, world) or not customer.enabled
		or customer.has_component(C_Death) or not EntityAvailability.contains(package, world)
		or not EntityAvailability.contains(item, world) or customer.id != opening_actor_id
		or CustomerInspectionQueries.owner_for(package) != customer
		or CustomerInspectionQueries.owner_for(item) != customer
	):
		return
	var rule: DEF_NpcFireAura = rule_for(customer)
	var inventory: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if rule == null or inventory == null or inventory.definition == null or inventory.quantity < 1:
		return
	var eligible: bool = false
	for definition: DEF_InventoryItem in rule.ignition_items:
		if definition.key == inventory.definition.key:
			eligible = true
			break
	if not eligible:
		return

	var visit: CustomerVisit = CustomerFlowQueries.visit_for(customer)
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	if (
		visit == null or visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or identity == null or identity.package_id != visit.package_id
		or condition == null or condition.opening != C_PackageState.Opening.OPENED
		or contents == null or not contents.released or visit.fire_opening_decided
	):
		return

	# Commit both outcomes before publishing a factory request: replay/reset cannot reroll.
	visit.fire_opening_decided = true
	visit.fire_opening_explosion = (
		CustomerInspectionRules.roll(visit, "fire_explosion/" + visit.package_id)
		< rule.opening_explosion_probability
	)
	if not visit.fire_opening_explosion:
		return
	var request: HazardSpawnRequest = HazardSpawnRequest.new()
	request.request_id = "npc_opening_fire/" + visit.package_id
	request.origin_id = opening_actor_id
	request.instigator_id = opening_actor_id
	request.origin = customer
	request.instigator = customer
	request.scene = load(BLAST_SCENE) as PackedScene
	request.definition = rule.opening_explosion
	request.world_pose = (item as Node as Node3D).global_transform
	HazardSpawnService.submit(request)
#endregion
