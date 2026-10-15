extends RefCounted
## Кодирует участников опасности ключами; живые связи восстанавливаются после создания всех
## сущностей.
class_name PersistentHazardState


## Снимает ключи источника, инициатора и следования вместо живых ссылок.
## Отсутствующий hazard даёт {}; недоступный origin/instigator кодируется пустым ключом.
static func capture(entity: Entity, root: Node) -> Dictionary:
	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	if hazard == null:
		return { }

	var hazard_references: Dictionary = ({
		"origin": _key(hazard.origin, root),
		"instigator": _key(hazard.instigator, root),
	})
	var binding: Relationship = HazardFollowService.binding(entity)
	if binding != null:
		var follow: R_HazardFollow = binding.relation as R_HazardFollow
		hazard_references.follow = ({
			"target": _key(binding.target as Entity, root),
			"offset": follow.local_offset,
			"on_loss": follow.on_loss,
		})
	return hazard_references


## Проверяет существование ключей и параметры сохранённого следования.
static func valid(hazard_references: Dictionary, records: Dictionary[String, Dictionary]) -> bool:
	for field: String in ["origin", "instigator"]:
		if (
			not hazard_references.get(field) is String
			or (
				not String(hazard_references[field]).is_empty()
				and not records.has(String(hazard_references[field]))
			)
		):
			return false
	if hazard_references.has("follow"):
		if not hazard_references.follow is Dictionary:
			return false

		var follow: Dictionary = hazard_references.follow as Dictionary
		if (
			not follow.get("target") is String or not records.has(String(follow.target))
			or not follow.get("offset") is Transform3D
			or not (follow.offset as Transform3D).is_finite()
			or follow.get("on_loss")
			not in [DEF_Hazard.OwnerLoss.DETACH, DEF_Hazard.OwnerLoss.DESPAWN]
		):
			return false
	return true


## Восстанавливает атрибуцию и R_HazardFollow, затем запрашивает геометрию без повторного взрыва.
## Требует valid и полный entities map; вызывается внутри подавления restore-реакций.
static func restore(
	hazard_references: Dictionary,
	entity: Entity,
	entities: Dictionary[String, Entity],
) -> void:
	var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
	if hazard == null:
		return

	hazard.origin = entities.get(String(hazard_references.get("origin", ""))) as Entity
	hazard.instigator = entities.get(String(hazard_references.get("instigator", ""))) as Entity
	var owner: Entity = null
	var follow: R_HazardFollow = null
	if hazard_references.has("follow"):
		var saved: Dictionary = hazard_references.follow as Dictionary
		follow = R_HazardFollow.new()
		owner = entities[String(saved.target)]
		follow.local_offset = saved.offset as Transform3D
		follow.on_loss = int(saved.on_loss) as DEF_Hazard.OwnerLoss
	HazardFollowService.replace(entity, owner, follow)
	# Geometry reconstruction is explicit and never replays spawn/damage reactions.
	if entity is E_ToxicArea:
		HazardGeometry.configure_toxic(entity as E_ToxicArea, hazard.definition as DEF_ToxicArea)
	elif entity is E_BloodArea:
		HazardGeometry.configure_blood(entity as E_BloodArea, hazard.definition as DEF_BloodArea)
	elif entity is E_Explosion:
		HazardGeometry.configure_explosion(
			entity as E_Explosion,
			hazard.definition as DEF_Explosion,
		)


## Снимает потерянное следование либо удаляет опасность согласно её политике.
static func reset_missing_owners() -> void:
	for entity: Entity in ECS.world.entities.duplicate():
		if not is_instance_valid(entity):
			continue

		var lifetime: C_HazardLifetime = entity.get_component(C_HazardLifetime) as C_HazardLifetime
		if lifetime != null and lifetime.owner_loss_pending:
			HazardLifecycle.retire(entity, ECS.world)
			continue

		var binding: Relationship = HazardFollowService.binding(entity)
		if binding == null or EntityAvailability.contains(binding.target, ECS.world):
			continue

		var follow: R_HazardFollow = binding.relation as R_HazardFollow
		if follow.on_loss == DEF_Hazard.OwnerLoss.DESPAWN:
			HazardLifecycle.retire(entity, ECS.world)
		else:
			entity.remove_relationship(binding)


static func _key(entity: Entity, root: Node) -> String:
	if not EntityAvailability.contains(entity, ECS.world):
		return ""

	var key: String = ActorIdentityRules.key_for(entity, root)
	# Временные клиенты/снаряды удаляются до снимка; сохраняются постоянные живые участники.
	return key
