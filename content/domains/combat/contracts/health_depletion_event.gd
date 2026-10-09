extends RefCounted
## Уведомление однократного эффекта истощения здоровья с необязательными VFX/SFX.
class_name HealthDepletionEvent

## Мировое событие после создания авторских игровых эффектов.
const EVENT: StringName = &"health_depletion_effects"

## Исходный результат урона; мировая поза отдельно сохраняется до удаления цели.
var cause: DamageResult = null
## Сохранённая мировая поза цели для эффектов после её удаления.
var world_pose: Transform3D = Transform3D.IDENTITY
## Необязательная сцена VFX; представление не владеет игровым созданием и уроном.
var vfx: PackedScene = null
## Необязательный звук представления эффекта.
var sfx: AudioStream = null
