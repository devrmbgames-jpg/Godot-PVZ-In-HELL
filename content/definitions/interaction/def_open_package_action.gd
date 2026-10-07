extends DEF_InteractionAction
## Запрашивает контекстное вскрытие; HP и назначение посылки не меняет.
class_name DEF_OpenPackageAction


#region Opening command
## Проверяет физический доступ к коробке source через PackageOpening.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return PackageOpening.can_open(actor, source)


## Передаёт запрос вскрытия source; наблюдатель повторно проверяет его перед фиксацией.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	PackageOpening.request_open(actor, source)


## A delayed accepted request never commits prolonged progress before the package was opened.
func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	var resolution: PackageOpenResult = PackageOpening.request_open(actor, source)
	return resolution.status == PackageOpenResult.Status.COMMITTED
#endregion
