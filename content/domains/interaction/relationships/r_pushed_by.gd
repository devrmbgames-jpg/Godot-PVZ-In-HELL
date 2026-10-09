extends Component
## Исключительная связь тележка → толкающий актор с обратимыми эффектами участия.
class_name R_PushedBy

## Собственный токен PUSH, освобождаемый при завершении толкания.
var capture_token: int = 0
## Исходное разрешение сна физической тележки для восстановления.
var previous_can_sleep: bool = true
## Эффекты участия применены; очистка выполняется один раз.
var lifecycle_applied: bool = false
