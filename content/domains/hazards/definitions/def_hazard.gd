extends GameDefinition
## Авторские настройки автономной опасности, читаемые без runtime-изменений ресурса.
class_name DEF_Hazard

enum Ownership {
	Independent,
	FollowOrigin,
}
enum OwnerLoss {
	Detach,
	Despawn,
}

## Конечный срок жизни в секундах симуляции; persistent отменяет ночной сброс, а не TTL.
@export_range(0.05, 3600.0) var lifetime_seconds: float = 40.0
## Сохраняет эффект при обычном ночном сбросе; собственный срок всё равно истекает.
@export var persistent: bool = false
## Следование перемещает нефизический эффект, а не создавшее его физическое тело.
@export var ownership: Ownership = Ownership.Independent
## После потери владельца отсоединяет эффект либо удаляет его.
@export var owner_loss: OwnerLoss = OwnerLoss.Detach
