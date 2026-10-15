extends RefCounted
## Команда намеренного вскрытия, независимая от повреждения и назначения посылки.
class_name PackageOpenRequest

## Канал World с запросом намеренного вскрытия.
const EVENT: StringName = &"package_open_requested"

## Заимствованный live actor; O_PackageOpening повторно проверяет доступ при исполнении.
var actor: Entity = null
## Заимствованная физическая коробка; запись запроса не удерживает lifetime Node.
var package: Entity = null
## Shared receipt: PackageOpening initializes it; O_PackageOpening resolves a dispatched command.
var resolution: PackageOpenResult = null
