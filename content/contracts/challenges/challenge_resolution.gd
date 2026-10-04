extends RefCounted
## Типизированный итог испытания; живые участники остаются в Relationships.
class_name ChallengeResolution

## Авторский ключ разрешённого испытания.
var challenge_key: StringName = &""
## Общий принятый итог, отдельно от текущего измерения условия.
var result: ChallengeResult.Type = ChallengeResult.Type.NONE
## Изменение удовлетворённости для контекста обслуживания.
var satisfaction_delta: int = 0
## Запрос эскалации при неудаче; атакой не владеет.
var request_escalation: bool = false
