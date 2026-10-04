extends RefCounted
## Разбирает синтаксис QA-цели без изменения мира; запись может существовать без физической коробки.
class_name DebugTargetResolver


#region Публичный синтаксис цели
## Разбирает self/target/#номер/pkg:/visit:/entity: либо raw package_id; отказ возвращает INVALID с error.
static func resolve(raw_target: String) -> DebugTarget:
	var result: DebugTarget = DebugTarget.new()
	result.query = raw_target.strip_edges()
	if result.query.is_empty():
		result.error = "target is empty"
		return result
	if not is_instance_valid(ECS.world):
		result.error = "ECS world is unavailable"
		return result

	if result.query == "self":
		return _resolve_self(result)
	if result.query == "target":
		return _resolve_interaction_target(result)
	if result.query.begins_with("#"):
		return _resolve_registration_number(result)
	if result.query.begins_with("pkg:"):
		return _resolve_package_id(result, result.query.trim_prefix("pkg:"))
	if result.query.begins_with("visit:"):
		return _resolve_visit(result, result.query.trim_prefix("visit:"))
	if result.query.begins_with("entity:"):
		return _resolve_entity_id(result, result.query.trim_prefix("entity:"))

	# Команды коробок также принимают точный стабильный package_id без префикса.
	return _resolve_package_id(result, result.query)


## Первая Entity с маркером ввода игрока либо null при отсутствии World.
static func player() -> Entity:
	if not is_instance_valid(ECS.world):
		return null
	return ECS.world.query.with_all([C_PlayerInputController]).execute_one()


#endregion

#region Игрок и наведение
static func _resolve_self(result: DebugTarget) -> DebugTarget:
	var actor: Entity = player()
	if not EntityAvailability.contains(actor, ECS.world):
		result.error = "player is unavailable"
		return result

	result.kind = DebugTarget.Kind.ENTITY
	result.entity = actor
	return result


static func _resolve_interaction_target(result: DebugTarget) -> DebugTarget:
	var actor: Entity = player()
	if not EntityAvailability.contains(actor, ECS.world):
		result.error = "player is unavailable"
		return result

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor == null or not is_instance_valid(interactor.target):
		result.error = "interaction target is unavailable"
		return result

	var target: Entity = interactor.target as Entity
	if not EntityAvailability.contains(target, ECS.world):
		result.error = "interaction target is unavailable"
		return result

	result.kind = DebugTarget.Kind.ENTITY
	result.entity = target
	if target.has_component(C_Package):
		var identity: C_Package = target.get_component(C_Package) as C_Package
		result.kind = DebugTarget.Kind.PACKAGE
		result.package_id = identity.package_id
		result.registration = _registration_for_package(identity.package_id)
		result.visit = _visit_for_package(identity.package_id)
	return result


#endregion

#region Записи и стабильные ID
static func _resolve_registration_number(result: DebugTarget) -> DebugTarget:
	var number_text: String = result.query.trim_prefix("#")
	if not number_text.is_valid_int():
		result.error = "invalid registration number: %s" % result.query
		return result

	var number: int = number_text.to_int()
	if number < 1:
		result.error = "registration number must be positive"
		return result

	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger == null:
		result.error = "package ledger is unavailable"
		return result

	for record: PackageRegistrationRecord in ledger.records:
		if record.active and record.number == number:
			var resolved: DebugTarget = _resolve_package_id(result, record.package_id)
			resolved.registration = record
			return resolved

	result.error = "active package #%03d was not found" % number
	return result


static func _resolve_package_id(result: DebugTarget, package_id: String) -> DebugTarget:
	var normalized: String = package_id.strip_edges()
	if normalized.is_empty():
		result.error = "package id is empty"
		return result

	var entity: Entity = _package_entity(normalized)
	var registration: PackageRegistrationRecord = _registration_for_package(normalized)
	var visit: CustomerVisit = _visit_for_package(normalized)
	if entity == null and registration == null and visit == null:
		result.error = "package was not found: %s" % normalized
		return result

	result.kind = DebugTarget.Kind.PACKAGE
	result.package_id = normalized
	result.entity = entity
	result.registration = registration
	result.visit = visit
	return result


static func _resolve_visit(result: DebugTarget, visit_id: String) -> DebugTarget:
	var normalized: String = visit_id.strip_edges()
	if normalized.is_empty():
		result.error = "visit id is empty"
		return result

	var visit: CustomerVisit = CustomerFlowService.find_visit(StringName(normalized))
	if visit == null:
		result.error = "visit was not found: %s" % normalized
		return result

	result.kind = DebugTarget.Kind.VISIT
	result.visit = visit
	result.package_id = visit.package_id
	result.entity = _package_entity(visit.package_id)
	result.registration = _registration_for_package(visit.package_id)
	return result


static func _resolve_entity_id(result: DebugTarget, entity_id: String) -> DebugTarget:
	var normalized: String = entity_id.strip_edges()
	if normalized.is_empty():
		result.error = "entity id is empty"
		return result

	for entity: Entity in ECS.world.entities:
		if EntityAvailability.contains(entity, ECS.world) and entity.id == normalized:
			result.kind = DebugTarget.Kind.ENTITY
			result.entity = entity
			if entity.has_component(C_Package):
				var identity: C_Package = entity.get_component(C_Package) as C_Package
				result.kind = DebugTarget.Kind.PACKAGE
				result.package_id = identity.package_id
				result.registration = _registration_for_package(identity.package_id)
				result.visit = _visit_for_package(identity.package_id)
			return result

	result.error = "live entity was not found: %s" % normalized
	return result


#endregion

#region Связанные данные заказа
static func _package_entity(package_id: String) -> Entity:
	for entity: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = entity.get_component(C_Package) as C_Package
		if identity != null and identity.package_id == package_id:
			return entity
	return null


static func _registration_for_package(package_id: String) -> PackageRegistrationRecord:
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger == null:
		return null

	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == package_id and record.active:
			return record
	return null


static func _visit_for_package(package_id: String) -> CustomerVisit:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if flow == null:
		return null

	for visit: CustomerVisit in flow.visits:
		if visit.package_id == package_id:
			return visit
	return null

#endregion
