@tool
extends Component
## Авторский профиль мастерской и transient бюджет размещения; история — C_Commerce.
class_name C_Crafting

## Единственный durable вход native точки; партия/льгота не дублируются на коробке.
const SAVE_FIELDS: Array[String] = ["profile"]

## Immutable рецепты, получатель подарков и доступная первая подсказка.
@export var profile: DEF_CraftingProfile = null
## Пауза повторов при занятом ящике, gameplay секунды, после restore начинается заново.
var retry_remaining: float = 0.0
## В CommandBuffer уже есть запрос для этой incarnation компонента.
var retry_queued: bool = false
## Версия queued запроса; in-place restore инвалидирует старый ticket.
var retry_revision: int = 0
## Резервы новых тел в текущем physics frame, до обновления физического space.
var reservations: Array[AABB] = []
## Native physics frame этих пространственных резервов.
var reservation_frame: int = -1
