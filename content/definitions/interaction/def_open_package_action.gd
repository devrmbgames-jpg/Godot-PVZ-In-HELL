extends DEF_InteractionAction
## Запрашивает контекстное вскрытие; HP и назначение посылки не меняет.
class_name DEF_OpenPackageAction


## Проверяет физический доступ к коробке source через PackageOpening.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return PackageOpening.can_open(actor, source)


## Передаёт запрос вскрытия source; наблюдатель повторно проверяет его перед фиксацией.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	PackageOpening.request_open(actor, source)
