extends Component
## Временное исполнение конкретного визита на теле; постоянные факты хранятся в CustomerVisit.
## Isolated часы ведёт S_CustomerClock; district — O_CustomerServiceClock по NpcDecisionReady.
## Переходы/одноразовые guards меняют явные service операции и владельцы scheduled фаз.
class_name C_CustomerAgent

enum Phase {
	APPROACHING,
	WAITING,
	DIALOGUE,
	WAITING_FOR_PACKAGE,
	RECEIVING,
	OPTIONAL_FITTING,
	LEAVING,
	AGGRESSIVE,
	FINISHED,
	WAITING_FOR_DARKNESS,
	GOING_TO_BOOTH,
	INSPECTING,
	RETURNING_FROM_BOOTH,
	QUEUED,
}

## ID заказа в журнале обслуживания текущей сессии.
var visit_id: StringName = &""
## Текущая фаза физического визита, включая очередь и частный осмотр.
var phase: Phase = Phase.APPROACHING
## GamePlay-секунды текущей фазы; enter_service_phase тоже сбрасывает, включая повтор той же фазы.
var elapsed: float = 0.0
## Номер уже объявлен в этом физическом визите; временная защита от повторной реплики.
var order_announced: bool = false
## Автоматическое знакомство уже открывало диалог в этом визите.
var dialogue_started: bool = false
## В этом осмотре уже была попытка открыть содержимое.
var inspection_open_attempted: bool = false
## Осмотр выявил причину отказа независимо от вероятности принятия заказа.
var inspection_force_refusal: bool = false


## Индекс следующего авторского маркера прогулки ожидающего получателя.
var waiting_point: int = 0
## Накопленные due-step секунды возле входа; O_CustomerServiceClock пишет только для district.
var entrance_wait_elapsed: float = 0.0
## Предупреждение и мерцание уже запущены в этом физическом визите.
var light_warning_started: bool = false

## Прежняя max_speed в м/с; NpcServiceRole восстанавливает, -1 означает отсутствие сохранения.
var original_walk_speed: float = -1.0

## Derived isolated-step phase snapshot; S_CustomerGreeting writes it, never persisted.
var scheduled_phase: int = -1
