extends Component
## Сохраняемый прогресс принадлежит затронутой цели и определяется постоянным action_id.
## Живое участие актора и инструмента принадлежит R_ProlongedOn и R_ProlongedUsing.
class_name C_ProlongedInteraction

## Прогресс отдельных действий этой цели, включая прерванные сеансы.
@export var actions: Array[ProlongedInteractionProgress] = []
