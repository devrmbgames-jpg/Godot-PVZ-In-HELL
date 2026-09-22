extends DEF_InteractionAction
## Registers the aimed parcel through a held scanner.
class_name DEF_ScanAction


func is_available(actor: Entity, source: Entity, target: Entity) -> bool:
	return PackageRegistrationService.can_scan(actor, source, target)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	var result: PackageScanResult = PackageRegistrationService.scan(actor, source, target)
	var scanner: E_Scanner = source as E_Scanner
	if scanner != null:
		scanner.scan_feedback.emit(result)
