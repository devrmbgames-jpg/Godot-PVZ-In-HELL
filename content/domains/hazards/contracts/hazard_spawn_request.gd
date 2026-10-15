extends RefCounted
## Однократный запрос создания опасности без знания о посылках, бочках и клиентах.
class_name HazardSpawnRequest

const EVENT: StringName = &"hazard_spawn_requested"

## Обязательный ID попытки; фабрика потребляет его даже при последующем отказе создания.
var request_id: String = ""
## Обязательный постоянный ID происхождения независимо от живой ссылки.
var origin_id: String = ""
## Постоянный ID инициатора для последующей атрибуции.
var instigator_id: String = ""
## Авторская автономная сцена опасности с нефизическим корнем E_Hazard.
var scene: PackedScene = null
## Необязательные авторские настройки, заменяющие определение prefab.
var definition: DEF_Hazard = null
## Мировая поза создания, зафиксированная производителем.
var world_pose: Transform3D = Transform3D.IDENTITY
## Необязательный живой источник для следования и исключений луча.
var origin: Entity = null
## Необязательный живой инициатор урона.
var instigator: Entity = null
## Снимок запрета исходящего урона; фабрика может усилить его, но не снять.
var damage_blocked: bool = false
