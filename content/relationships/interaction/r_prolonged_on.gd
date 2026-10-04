extends Component
## Актор → затронутая цель: единственный активный длительный сеанс для актора и цели.
## Сервис жизненного цикла создаёт и проверяет связь, освобождая токен захвата ввода.
class_name R_ProlongedOn

## Авторское действие текущего сеанса.
var action: DEF_InteractionAction = null
## Канал кнопки, удерживаемой для продолжения сеанса.
var input_slot: DEF_InteractionAction.Slot = DEF_InteractionAction.Slot.USE
## Токен захвата ввода; освобождается при очистке связи.
var capture_token: int = 0
## Исполняется синхронный эффект; вложенная очистка не сбрасывает READY до фиксации результата.
var finishing: bool = false
## Временные ресурсы связи уже освобождены.
var cleaned: bool = false
