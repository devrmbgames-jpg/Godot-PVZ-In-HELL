extends GameDefinition
## Авторские ставки расчётов посылок и базовая оплата выдачи.
class_name DEF_Economy

## Процент стоимости при добровольном выкупе посылки.
@export_range(0, 1000) var buyout_percent: int = 100
## Процент стоимости штрафа за потерю.
@export_range(0, 1000) var lost_percent: int = 120
## Процент стоимости штрафа за отказ игрока.
@export_range(0, 1000) var refusal_percent: int = 150
## Процент стоимости штрафа за подтверждённый обман.
@export_range(0, 1000) var fraud_percent: int = 200
## Повышенная ставка пропущенной регистрации относительно потери, отказа и обмана.
@export_range(0, 1000) var missed_registration_percent: int = 300
## Базовая оплата успешной выдачи в целых денежных единицах.
@export var delivery_payment: int = 100
