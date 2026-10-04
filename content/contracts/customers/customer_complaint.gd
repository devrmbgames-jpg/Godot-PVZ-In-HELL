extends Resource
## Отложенное рассмотрение жалобы и ограниченный срок ответа на ложное обвинение.
class_name CustomerComplaint

enum Reason { NOT_DELIVERED, DAMAGED }
enum Outcome { PENDING, CONFIRMED, FALSE_CLAIM, WAIVED_PLAYER_DEFEAT, ALREADY_SETTLED, NO_LIVING_CLAIMANT }

## ID жалобы, используемый как ключ однократного денежного последствия.
@export var complaint_id: StringName = &""
## Предмет обвинения: отсутствие выдачи либо повреждение коробки.
@export var reason: Reason = Reason.NOT_DELIVERED
## День создания жалобы.
@export var created_day: int = 0
## Первый день возможного рассмотрения без принудительного обхода задержки.
@export var resolve_day: int = 0
## Зафиксированное решение; только PENDING допускает обычное повторное рассмотрение.
@export var outcome: Outcome = Outcome.PENDING
## День фактического решения по жалобе.
@export var resolved_day: int = 0
## Первый включённый день разрешённого ответа игрока на ложную жалобу.
@export var retaliation_start_day: int = 0
## Первый исключённый день срока ответа; по умолчанию интервал длится ровно семь дней.
@export var retaliation_end_day: int = 0
## Денежное последствие жалобы со знаком для отчёта, в валюте игры.
@export var money_delta: int = 0
