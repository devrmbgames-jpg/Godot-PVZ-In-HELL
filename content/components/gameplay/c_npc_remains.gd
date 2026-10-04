extends Component
## Авторский дроп и сохраняемый запрет повторной выдачи; реакцию на смерть исполняет Observer.
class_name C_NpcRemains

## Авторский профиль физических кусков мяса и дополнительной добычи.
@export var definition: DEF_NpcRemains = null
## Партия добычи уже принята; сохраняется для защиты от повторной смерти/восстановления.
@export var released: bool = false
