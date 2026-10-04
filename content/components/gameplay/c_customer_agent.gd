extends Component
## Временное исполнение конкретного визита на теле; постоянные факты хранятся в CustomerVisit.
class_name C_CustomerAgent

enum Phase { APPROACHING, WAITING, DIALOGUE, WAITING_FOR_PACKAGE, RECEIVING, OPTIONAL_FITTING, LEAVING, AGGRESSIVE, FINISHED, WAITING_FOR_DARKNESS, GOING_TO_BOOTH, INSPECTING, RETURNING_FROM_BOOTH, QUEUED }

## ID заказа в журнале обслуживания текущей сессии.
var visit_id: StringName = &""
## Текущая фаза физического визита, включая очередь и частный осмотр.
var phase: Phase = Phase.APPROACHING
## Время в текущей фазе, в секундах; переход обслуживания сбрасывает таймер.
var elapsed: float = 0.0
## Номер уже объявлен в этом физическом визите; временная защита от повторной реплики.
var order_announced: bool = false
## Автоматическое знакомство уже открывало диалог в этом визите.
var dialogue_started: bool = false
## В этом осмотре уже была попытка открыть содержимое.
var inspection_open_attempted: bool = false
## Осмотр выявил причину отказа независимо от вероятности принятия заказа.
var inspection_force_refusal: bool = false
