extends Component
## Авторитетная связь груз → тележка с обратимыми настройками физического ограничения.
class_name R_CartCargo

## Сохранённое положение груза в локальных координатах тележки.
var local_pose: Transform3D = Transform3D.IDENTITY
## Исходный режим custom_integrator тела груза.
var previous_custom_integrator: bool = false
## Исходное разрешение сна тела груза.
var previous_can_sleep: bool = true
## Исключение столкновений с тележкой добавлено этой связью и подлежит снятию.
var added_exception: bool = false
## Ограничение груза применено; повторная очистка не повторяет физические эффекты.
var lifecycle_applied: bool = false
