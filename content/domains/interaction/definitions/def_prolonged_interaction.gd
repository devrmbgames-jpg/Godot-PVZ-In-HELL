extends GameDefinition
## Авторские правила времени контекстного действия, отдельно от изменяемого прогресса.
class_name DEF_ProlongedInteraction

enum ResetPolicy { DECAY, INSTANT, ON_COMPLETE, NEVER }

## Длительность полного выполнения, в секундах.
@export_range(0.01, 60.0, 0.01, "or_greater") var duration_seconds: float = 6.0
## Правило потери или сохранения прогресса при прерывании и завершении.
@export var reset_policy: ResetPolicy = ResetPolicy.INSTANT
## Доля прогресса, теряемая за секунду простоя, независимо от длительности действия.
@export_range(0.0, 10.0, 0.01, "or_greater") var decay_per_second: float = 0.125
