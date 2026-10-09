extends RefCounted
## Запрос сброса опасностей; persistent защищает от обычного сброса, а не собственного TTL.
class_name HazardResetRequest

const EVENT: StringName = &"hazard_reset_requested"

## Полная очистка включает persistent-эффекты, например при сбросе сценария.
var include_persistent: bool = false
