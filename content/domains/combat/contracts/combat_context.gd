extends Resource
## Постоянная атрибуция боя без живых ссылок участника, оружия и цели.
class_name CombatContext

enum Reason { ORDINARY_ATTACK, SELF_DEFENSE, FRAUD_ESCALATION, JUSTIFIED_RETALIATION, CHALLENGE_ESCALATION }

## Причина конфликта для последующего учёта результата.
@export var reason: Reason = Reason.ORDINARY_ATTACK
## День снимка; 0 при отсутствии цикла.
@export var day: int = 0
## Постоянный ID связанного клиента, если есть случай обслуживания.
@export var customer_id: StringName = &""
## ID конкретного случая обслуживания.
@export var visit_id: StringName = &""
## Инициатор запроса распознан как игрок.
@export var actor_is_player: bool = false
## Авторский ключ удара оружия, если источник имеет C_MeleeWeapon.
@export var weapon_key: StringName = &""
