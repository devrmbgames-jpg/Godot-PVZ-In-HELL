extends Component
## Защита получателя от столкновения; использование плёнки может менять уровень.
class_name C_ImpactProtection

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["tier"]

## Полностью блокирует физическую тяжесть до этого уровня; более сильный удар не ослабляется.
@export var tier: ImpactResult.Severity = ImpactResult.Severity.None
