extends Component
## Transient floor setup/contact: activation запрашивает эффект, S_FloorHazard измеряет контакт.
class_name C_FloorChallenge

## Запрос автономной плоскости уже отправлен; повтор запрещён.
var spawn_requested: bool = false
## Transient request identity of this one-shot session; activation is its only writer.
var spawn_request_id: String = ""
## S_FloorHazard пишет реальный support contact; ChallengeService cleanup сбрасывает.
var touching_danger: bool = false
