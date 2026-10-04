extends Component
## Постоянный ID и признаки предмета для проверки доступа, независимо от конкретного класса ключа.
class_name C_AccessItem

## Авторский ключ предмета для точного условия доступа.
@export var item_id: StringName = &""
## Признаки предмета для составного требования доступа.
@export var tags: Array[StringName] = []
