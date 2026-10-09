extends Resource
## Авторское соответствие вида коробки политике получателя и задержке его визита.
class_name DEF_CustomerEvent

## Ключ DEF_Package из ассортимента поставки.
@export var package_key: StringName = &"books"
## Получение требует записи регистрации коробки; свободная жизнь NPC от неё не зависит.
## Отключать только у встречи с другой авторской причиной визита.
@export var requires_registered_package: bool = true
## Задержка от дня поставки до визита, в днях; -1 отключает назначение получателя.
@export var arrival_delay_days: int = 0
## Правила обслуживания конкретного заказа, отдельно от постоянной личности NPC.
@export var customer: DEF_Customer = null
