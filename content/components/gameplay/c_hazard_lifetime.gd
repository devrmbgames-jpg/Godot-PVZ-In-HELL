extends Component
## Срок автономной опасности, независимый от наличия создавшей Entity.
class_name C_HazardLifetime

## Остаток срока жизни в секундах, заданный при создании из определения.
var remaining_seconds: float = 0.0
## Защита от обычного ночного сброса отдельно от TTL.
var persistent: bool = false

## Ожидающий однократный эффект удерживает отсчёт TTL до разрешения.
var awaiting_resolution: bool = false

## Временное ожидаемое удаление при потере владельца; такой эффект исключается из снимка.
var owner_loss_pending: bool = false
