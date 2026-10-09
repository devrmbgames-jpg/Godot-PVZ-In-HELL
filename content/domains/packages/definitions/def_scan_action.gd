extends DEF_InteractionAction
## Регистрирует коробку под лучом взаимодействия через удерживаемый сканер.
class_name DEF_ScanAction


## Проверяет сканер, коробку под лучом и дистанцию через сервис регистрации.
func is_available(actor: Entity, source: Entity, target: Entity) -> bool:
	return PackageRegistrationService.can_scan(actor, source, target)


## Повторно проверяет сканирование, регистрирует коробку и сообщает результат сигналом сканера.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	var result: PackageScanResult = PackageRegistrationService.scan(actor, source, target)
	var scanner: E_Scanner = source as E_Scanner
	if scanner != null:
		scanner.scan_feedback.emit(result)
