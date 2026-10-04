extends Component
## Состояние одного удара игрока; живое оружие связано через R_AttackWeapon.
class_name C_Combat

enum Phase { READY, WINDUP, ACTIVE, RECOVERY }

## Текущая фаза единственного удара.
var phase: Phase = Phase.READY
## Время с начала удара в секундах.
var elapsed: float = 0.0
## Определение текущего удара; null в READY.
var strike: DEF_MeleeAttack = null
## Запрос попадания принят; второй успешный запрос этого удара запрещён.
var hit_committed: bool = false
