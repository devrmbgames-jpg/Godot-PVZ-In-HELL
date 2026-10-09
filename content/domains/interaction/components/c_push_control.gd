extends Component
## Производный кеш актора; авторитетность толкания принадлежит R_PushedBy на тележке.
class_name C_PushControl

## Кеш толкаемой тележки, проверяемый по её живой связи R_PushedBy.
var pushed_object: Entity = null
