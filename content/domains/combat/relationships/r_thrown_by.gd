extends Component
## Связывает намеренно брошенный источник с вызвавшим бросок участником.
class_name R_ThrownBy

## Остаток GamePlay-секунд; S_ThrowLifetime уменьшает, ThrowContext снимает связь.
var remaining_seconds: float = 0.0
## Физический такт броска; контакт того же такта не расходует бонус.
var armed_tick: int = -1
