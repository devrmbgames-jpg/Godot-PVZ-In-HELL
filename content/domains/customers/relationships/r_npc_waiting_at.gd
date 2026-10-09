extends Component
## Живое резервирование ожидания у стойки; один визит и авторский маршрут на участника.
class_name R_NpcWaitingAt

## ID заказа, для которого получатель ждёт у ПВЗ.
@export var visit_id: StringName = &""
## Номер маршрута ожидания; -1 означает первого клиента у входа.
@export var route_index: int = -1
