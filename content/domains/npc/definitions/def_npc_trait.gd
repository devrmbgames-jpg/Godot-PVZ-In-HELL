@tool
extends GameDefinition
## Shared immutable правило нечисти; S_NpcTraits накапливает exposure в GamePlay seconds.
## Typed capabilities могут иметь отдельного владельца и собственную проверку конфигурации.
class_name DEF_NpcTrait

enum Kind {
	GAZE_AVERSION,
	LIGHT_AVERSION,
	FIRE_AURA,
	DARK_PREDATOR,
	STRENGTH_TEST,
	PROVOCATEUR,
	RIDDLE,
	CAPABILITY,
}

## Вид поведения, задаваемый этой особенностью.
@export var kind: Kind = Kind.GAZE_AVERSION
## Понятное предупреждение перед эскалацией.
@export var warning_text: String = "Не испытывай моё терпение."
## Понятное игроку объяснение контрмеры.
@export var countermeasure: String = ""
## Длительность воздействия до предупреждения, в секундах.
@export_range(0.1, 30.0) var warning_seconds: float = 1.5
## Дополнительное время воздействия после предупреждения до реакции.
@export_range(0.1, 60.0) var reaction_seconds: float = 3.0
## Дальность legacy правила в метрах; реальную геометрию FIRE_AURA задаёт aura.radius.
@export_range(0.2, 20.0) var radius: float = 3.0
## Порог света для светобоязни и охоты в темноте.
@export_range(0.0, 1.0) var light_threshold: float = 0.35
## Единая настройка реального урона ауры, радиуса и прогноза риска.
@export var aura: DEF_ToxicArea = null
## Особенности, несовместимые с этим правилом.
@export var incompatible: Array[Kind] = []
## Stable-key exclusions support authored combinations independently of the behavior kind.
@export var incompatible_keys: Array[StringName] = []
## Косинус угла длительного взгляда игрока.
@export_range(0.5, 1.0) var gaze_alignment: float = 0.96


#region Authored capability validation
## Legacy traits retain their stable kinds; typed capabilities validate their own tuning.
func valid_configuration() -> bool:
	return kind >= Kind.GAZE_AVERSION and kind <= Kind.RIDDLE
#endregion
