extends Component
## NPC-only authored slots and execution state. Opponent authority is R_CombatTarget.
class_name C_NpcCombat

const MAX_VARIANTS: int = 3
enum Kind { MELEE, RANGED }
enum Phase { READY, WINDUP, ACTIVE, RECOVERY }

@export var melee_attacks: Array[DEF_NpcAttack] = []
@export var ranged_attacks: Array[DEF_NpcAttack] = []
## Future behavior adapters disable selection here; attack execution/cooldown still runs.
@export var automatic_attack_selection: bool = true
var phase: Phase = Phase.READY
var kind: Kind = Kind.MELEE
var variant: int = -1
var attack: DEF_NpcAttack = null
var elapsed: float = 0.0
var cooldown_remaining: float = 0.0
var effect_committed: bool = false
var animation_driven: bool = false
var aggression_reason: CombatContext.Reason = CombatContext.Reason.ORDINARY_ATTACK
