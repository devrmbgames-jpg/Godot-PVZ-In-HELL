extends Component
## Наборы и исполнение атак NPC; живой противник принадлежит R_CombatTarget.
class_name C_NpcCombat

const MAX_VARIANTS: int = 3
enum Kind { MELEE, RANGED }
enum Phase { READY, WINDUP, ACTIVE, RECOVERY }

## Авторский ближний набор; используются не более MAX_VARIANTS первых элементов.
@export var melee_attacks: Array[DEF_NpcAttack] = []
## Авторский дальний набор; используются не более MAX_VARIANTS первых элементов.
@export var ranged_attacks: Array[DEF_NpcAttack] = []
## Отключает автоматический выбор для внешнего AI; исполнение начатой атаки продолжается.
@export var automatic_attack_selection: bool = true
## Текущая фаза исполнения атаки NPC.
var phase: Phase = Phase.READY
## Набор текущей атаки.
var kind: Kind = Kind.MELEE
## Индекс текущей атаки; -1 вне исполнения.
var variant: int = -1
## Зафиксированное определение текущей атаки.
var attack: DEF_NpcAttack = null
## Время исполнения в секундах.
var elapsed: float = 0.0
## Остаток задержки следующей атаки в секундах.
var cooldown_remaining: float = 0.0
## Попытка эффекта уже выполнена, включая промах.
var effect_committed: bool = false
## Эффект и завершение ожидаются из method-track доступной анимации.
var animation_driven: bool = false
## Причина агрессии для снимка атрибуции.
var aggression_reason: CombatContext.Reason = CombatContext.Reason.ORDINARY_ATTACK

## Session-local start/cancel generation; queued progression cannot advance a replacement attack.
var execution_generation: int = 0
