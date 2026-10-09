extends Component
## Исключительная связь транспортная тележка → водитель.
class_name R_CartDrivenBy

## Собственный токен TRANSPORT, освобождаемый при завершении управления.
var capture_token: int = 0
## Обратимый эффект участия уже применён.
var lifecycle_applied: bool = false
