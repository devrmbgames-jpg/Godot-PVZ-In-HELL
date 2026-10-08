extends Component
## Авторитетная связь предмет → держатель со слотом и обратимыми побочными эффектами хвата.
class_name R_HeldBy

## Физический слот держателя, занимаемый этой связью.
var slot: C_Grabbable.HoldSlot = C_Grabbable.HoldSlot.CARRY
## Снимок фактических авторских либо стандартных правил этого хвата.
var profile: GrabControlProfile = null
## Накопленное ручное вращение относительно точки удержания.
var rotation_offset: Quaternion = Quaternion.IDENTITY
## Фактическая дистанция Carry этого хвата, в метрах.
var hold_distance: float = 0.0
## Исходный can_sleep для восстановления; принадлежность определяется самой живой связью.
var previous_can_sleep: bool = true
## Исключение столкновений с держателем добавлено этим хватом и подлежит снятию.
var added_collision_exception: bool = false
## Последняя мировая точка удержания для оценки скорости.
var previous_anchor_position: Vector3 = Vector3.ZERO
## Последняя точка пригодна для вычисления относительного движения.
var anchor_sample_valid: bool = false
## Instance ID точки удержания для обнаружения смены якоря.
var previous_anchor_id: int = 0
## Оставшееся время сглаживания смены точки удержания, в секундах.
var anchor_transition_remaining: float = 0.0
## Токен управления, принадлежащий этому хвату; освобождается при завершении.
var capture_token: int = 0
## Признак применённых эффектов наблюдателя для очистки; не используется как признак владения.
var lifecycle_applied: bool = false
