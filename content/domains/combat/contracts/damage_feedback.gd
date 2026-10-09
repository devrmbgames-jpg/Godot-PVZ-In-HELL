extends RefCounted
## Снимок для представления без живых ссылок, пригодный после удаления повреждённой Entity.
class_name DamageFeedback

enum Audience { PLAYER, PACKAGE, OTHER }

## Категория получателя для выбора интерфейсной реакции.
var audience: Audience = Audience.OTHER
## Снимок ID повреждённой сущности.
var target_id: String = ""
## Скрытый ID посылки либо пустая строка для других целей.
var package_id: String = ""
## Тип фактически применённого урона.
var damage_type: DamageRequest.Type = DamageRequest.Type.GENERIC
## Фактическая потеря здоровья, а не исходная сумма запроса.
var amount: float = 0.0
## Мировое место повреждения для обратной связи.
var position: Vector3 = Vector3.ZERO
## Удар вызвал истощение здоровья.
var depleted: bool = false
## Инициатор распознан как игрок при создании снимка.
var actor_is_player: bool = false
