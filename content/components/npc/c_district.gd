extends Component
## Сессия района хранит личности, календарные фиксации и заселение.
class_name C_District

## Авторская конфигурация района.
@export var definition: DEF_District = null
## Живые личности и история погибших жителей.
@export var people: Array[NpcRecord] = []
## Добровольные доставки, включая сохраняемые завершённые результаты.
@export var home_deliveries: Array[NpcHomeDelivery] = []
## Производный слабый кеш тела с проверкой участия в мире; не заменяет отношения.
var body_references: Dictionary[StringName, WeakRef] = {}
## Ручные зоны света текущего уровня; не сохраняются.
var lighting_context: NpcLightingContext = null
## Ревизия регистрации для обновления списка зон света.
var lighting_revision: int = -1
## Звуковые события до следующего обновления восприятия; не сохраняются.
var noises: Array[NpcNoise] = []
## Временная последовательность звуковых событий.
var next_noise_sequence: int = 1
## Временная последовательность запросов ауры; действующие эффекты восстанавливаются после загрузки.
var next_aura: int = 1
## Очередь маршрутов из постоянных ID; отменённые заявки пропускаются.
var pending_routes: Array[StringName] = []
## Физический кадр последнего сброса лимита планирования.
var route_planning_frame: int = -1
## Количество выполненных планов за текущий физический кадр.
var route_plans_this_frame: int = 0
## Накопитель частоты шагов игрока; не сохраняется.
var player_step_elapsed: float = 0.0
## Порядок появления на обслуживании, независимый от порядка архетипов GECS.
@export var next_service_order: int = 1
## Номер новой личности, возрастающий на протяжении сессии.
@export var next_person: int = 1
## Последовательный ID зафиксированного социального инцидента.
@export var next_incident: int = 1
## Последнее подготовленное утро предотвращает повтор заселения при попытке записи.
@export var prepared_morning: int = 0
## Первое утро возможного заселения; ноль означает отсутствие активной волны.
@export var replacement_morning: int = 0
## Ключ дня и фазы для лимита самостоятельных конфликтов.
@export var conflict_phase: StringName = &""
## Самостоятельные конфликты, уже начатые в текущей фазе.
@export var ambient_conflicts: int = 0
