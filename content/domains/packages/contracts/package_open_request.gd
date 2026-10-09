extends RefCounted
## Команда намеренного вскрытия, независимая от повреждения и назначения посылки.
class_name PackageOpenRequest

## Канал World с запросом намеренного вскрытия.
const EVENT: StringName = &"package_open_requested"

## Живая сущность инициатора вскрытия.
var actor: Entity = null
## Физическая коробка, которую требуется открыть.
var package: Entity = null
## Receipt shared with the caller; the Observer is its only terminal-state writer.
var resolution: PackageOpenResult = null
