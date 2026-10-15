extends Component
## Состояние одного удара игрока; живое оружие связано через R_AttackWeapon.
class_name C_Combat

enum Phase {
	READY,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

## Фаза удара: CombatService начинает/отменяет, S_PlayerMelee продвигает по часам.
var phase: Phase = Phase.READY
## Время с начала удара в GamePlay-секундах.
var elapsed: float = 0.0
## Определение текущего удара; null в READY.
var strike: DEF_MeleeAttack = null
## Хотя бы один запрос scan принят; следующие scan запрещены, текущий допускает maximum_targets.
var hit_committed: bool = false

## Session-local start/cancel generation; queued progression cannot advance a replacement attack.
var execution_generation: int = 0
