extends Component
## Факты создания эффекта и контакта участника с опасной плоскостью.
class_name C_FloorChallenge

## Запрос автономной плоскости уже отправлен; повтор запрещён.
var spawn_requested: bool = false
## Последнее измерение реального контакта опоры с плоскостью.
var touching_danger: bool = false
