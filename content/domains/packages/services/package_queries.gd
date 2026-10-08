extends RefCounted
## Читает журнал склада и живые посылки без регистрации или изменения заказа.
class_name PackageQueries

#region Чтение состояния
## Находит живую коробку по постоянному package_id, отдельно от номера регистрации.
static func find_live_package(package_id: String) -> Entity:
	if not is_instance_valid(ECS.world):
		return null

	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		if identity != null and identity.package_id == package_id:
			return parcel
	return null

## Читает журнал текущего склада, независимо от номера дня.
static func ledger() -> C_PackageLedger:
	if not is_instance_valid(ECS.world):
		return null

	var session: Entity = ECS.world.query.with_all([C_PackageLedger]).execute_one()
	return session.get_component(C_PackageLedger) as C_PackageLedger if session != null else null

## Возвращает соответствие ID живым C_PackageState для чтения интерфейсом; ссылки компонентов не являются копиями.
static func live_states() -> Dictionary[String, C_PackageState]:
	var result: Dictionary[String, C_PackageState] = {}
	if not is_instance_valid(ECS.world):
		return result

	for parcel: Entity in ECS.world.query.with_all([C_Package, C_PackageState]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
		result[identity.package_id] = state
	return result
#endregion
