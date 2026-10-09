extends Component
## Постоянный ID дома; жители и обязательства принадлежат сессии района.
class_name C_NpcAddress

#region Persistent identity
## Closed save fields; the authored place owns presentation and tuning.
const SAVE_FIELDS: Array[String] = ["address_id"]

## Адрес, разрешаемый через авторскую точку района.
@export var address_id: StringName = &""

#endregion
