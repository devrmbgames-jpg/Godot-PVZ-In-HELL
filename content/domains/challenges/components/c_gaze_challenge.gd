extends Component
## Derived observation: S_ChallengeGaze вызывает GazeTrackingGeometry для заполнения/очистки sample.
## Часы находятся в C_Challenge, actor binding — R_ChallengeActor; codec этот cache не сохраняет.
class_name C_GazeChallenge

## Геометрия текущего измерения пригодна для проверки условия.
var sample_valid: bool = false
## Расстояние до точки взгляда в метрах.
var distance: float = 0.0
## Угол фактического взгляда к цели в градусах.
var angle_degrees: float = 0.0
## Цель находится в авторской дальности.
var within_range: bool = false
## Цель находится внутри авторского сектора.
var within_angle: bool = false
## Первое препятствие не скрывает носителя испытания.
var line_of_sight: bool = false
## Есть направленный взгляд с видимой целью.
var attention: bool = false
## Производный флаг предупреждения, обновляемый системой отдельно от измерения.
var warning_active: bool = false
