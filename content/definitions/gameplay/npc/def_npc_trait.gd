extends GameDefinition
## Авторское правило нечисти, предупреждение и доступная контрмера.
class_name DEF_NpcTrait

enum Kind { GAZE_AVERSION, LIGHT_AVERSION, FIRE_AURA, DARK_PREDATOR, STRENGTH_TEST, PROVOCATEUR, RIDDLE }

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
## Дальность особенности, включая радиус огненной ауры, в метрах.
@export_range(0.2, 20.0) var radius: float = 3.0
## Порог света для светобоязни и охоты в темноте.
@export_range(0.0, 1.0) var light_threshold: float = 0.35
## Единая настройка реального урона ауры, радиуса и прогноза риска.
@export var aura: DEF_ToxicArea = null
## Особенности, несовместимые с этим правилом.
@export var incompatible: Array[Kind] = []
## Косинус угла длительного взгляда игрока.
@export_range(0.5, 1.0) var gaze_alignment: float = 0.96
