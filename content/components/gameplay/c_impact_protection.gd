extends Component
## Защита получателя от столкновения; использование плёнки может менять уровень.
class_name C_ImpactProtection

## Полностью блокирует физическую тяжесть до этого уровня; более сильный удар не ослабляется.
@export var tier: ImpactResult.Severity = ImpactResult.Severity.None
