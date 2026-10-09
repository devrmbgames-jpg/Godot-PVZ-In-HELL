extends Component
## Авторские контекстные действия и резервы кнопок сущности.
class_name C_InteractionActionSet

## Общий авторский набор действий, проверяемых resolver без изменения ресурсов.
@export var actions: Array[DEF_InteractionAction] = []
## PRIMARY означает применение предмета; resolver сопоставляет ему любую физическую руку.
## Занятая соответствующая рука резервирует ввод даже без доступной цели.
@export_flags("Interact:1", "Use:2", "Primary:4", "Secondary:8") var reserved_slots: int = 0
