extends Component
## Подключает физический урон к здоровью через переиспользуемые авторские настройки.
class_name C_ImpactReceiver

## Пороги контакта и преобразование энергии; ресурс читается без runtime-правок.
@export var profile: DEF_ImpactProfile = preload(
	"res://content/domains/combat/definitions/def_impact_default.tres"
)
