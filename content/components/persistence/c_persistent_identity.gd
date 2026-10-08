extends Component
## Постоянный ключ runtime-сущности; авторские экземпляры могут использовать устойчивый путь сцены.
class_name C_PersistentIdentity

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["key"]

## Непустой устойчивый ключ экземпляра; не наследуется новым жителем.
@export var key: String = ""
