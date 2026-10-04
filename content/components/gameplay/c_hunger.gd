extends Component
## Состояние накопленного голода; пороги и множители задаёт авторская политика.
class_name C_Hunger

enum Tier { NORMAL, HUNGRY, STARVING }

## Авторская политика порогов и эффектов; null отключает рост/усиление.
@export var policy: DEF_HungerPolicy = null
## Текущий накопленный голод, 0–maximum; еда уменьшает значение.
@export var value: float = 0.0
## Суммарное активное время роста в секундах, без ночи, паузы и смерти.
var active_seconds: float = 0.0
