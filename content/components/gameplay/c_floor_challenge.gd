extends Component
## Факты создания эффекта и контакта участника с опасной плоскостью.
class_name C_FloorChallenge

## Запрос автономной плоскости уже отправлен; повтор запрещён.
var spawn_requested: bool = false
## Transient request identity of this one-shot session; activation is its only writer.
var spawn_request_id: String = ""
## Последнее измерение реального контакта опоры с плоскостью.
var touching_danger: bool = false
