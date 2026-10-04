extends GameDefinition
## Настройки населения, заселения, маршрутов и восприятия района.
class_name DEF_District
## Освещённость вне ручных зон; не зависит от визуального ambient.
@export_range(0.0, 1.0) var ambient_light: float = 0.05
## Радиус опасности возле места отдыха, блокирующей сон, в метрах.
@export_range(0.1, 8.0) var sleep_danger_radius: float = 1.5
## Разговор остаётся открытым только в пределах этой дистанции, в метрах.
@export_range(1.0, 10.0) var conversation_range: float = 4.0
## Допуск прибытия к физической добыче, в метрах.
@export_range(0.2, 2.0) var loot_distance: float = 0.8
## Уровень голода, при котором NPC может съесть доступную еду.
@export_range(0.0, 100.0) var npc_food_threshold: float = 30.0
## Голод, который может обосновать допустимое по риску самостоятельное нападение.
@export_range(0.0, 100.0) var npc_attack_hunger: float = 80.0
## Начальный голод; на карте растёт по существующим правилам Hunger.
@export_range(0.0, 100.0) var npc_start_hunger: float = 20.0
## Имена новых жителей из совместимого пула; последовательность различает повторы.
@export var replacement_names: PackedStringArray = ["Счетовод", "Грач", "Моль", "Сажа", "Свечник", "Тихоня", "Нитка", "Дымник"]
## Интервал проверки риска и повторной попытки пути, а не полного перепланирования.
@export_range(0.1, 5.0) var route_interval: float = 0.6
## Лимит синхронных планов маршрута за один физический кадр.
@export_range(1, 16) var route_plans_per_frame: int = 1
## Максимальное ожидание перед отказом от недостижимого занятия, в секундах.
@export_range(1.0, 120.0) var route_timeout: float = 20.0
## Горизонтальное продвижение, сбрасывающее таймер застревания, в метрах.
@export_range(0.05, 1.0) var route_progress_distance: float = 0.15
## Дополнительный зазор локального обхода движущейся опасности, в метрах.
@export_range(0.1, 3.0) var local_detour_margin: float = 0.5
## Упорядоченные ID теневого прохода для движения светобоязненных NPC в обе стороны.
@export var shade_route: PackedStringArray = []
## Заданная точка отступления от света; поиск тёмных мест не выполняется.
@export var shade_refuge: StringName = &""
## Допуск промежуточной точки пути, независимый от прибытия к получателю.
@export_range(0.1, 1.0) var waypoint_distance: float = 0.5
## Горизонтальный радиус ухода через проход; учитывает край navmesh и зазор тела, в метрах.
@export_range(0.3, 3.0) var portal_arrival_distance: float = 1.0

## Начальные личности и пул профилей для заселения.
@export var profiles: Array[DEF_NpcProfile] = []
## Постоянные дома, проходы, занятия и узлы маршрутов.
@export var places: Array[DEF_DistrictPlace] = []
## Целевое количество местных жителей.
@export_range(1, 64) var resident_count: int = 8
## Целевое количество постоянных приезжих.
@export_range(0, 64) var visitor_count: int = 4
## Количество вакансий для запуска местного заселения.
@export_range(1, 64) var replacement_threshold: int = 2
## Количество переходов к утру перед прибытием замены.
@export_range(1, 30) var replacement_delay_days: int = 2
## Интервал обновления решений и восприятия, в секундах.
@export_range(0.05, 1.0) var decision_interval: float = 0.2
## Лимит самостоятельных конфликтов NPC за фазу.
@export_range(0, 10) var ambient_conflicts_per_phase: int = 1
## Лимит инициаторов нападений при выборе новых местных профилей.
@export_range(0, 8) var maximum_conflict_initiators: int = 2
## Пауза до выбора следующего простого занятия, в секундах.
@export_range(1.0, 300.0) var activity_seconds: float = 30.0
## Явные маршруты ожидания, относительно корня уровня.
@export var service_routes_path: NodePath = NodePath("Entityes/DeliveryCounter/Entry/NpcServiceRoutes")
## Число подготовленных следующих клиентов, помимо обслуживаемого.
@export_range(0, 2) var prepared_customer_count: int = 2
## Предел безрезультатного прибытия/ожидания света после подхода, в секундах.
@export_range(5.0, 180.0) var service_wait_timeout: float = 60.0
## Максимальная пауза передачи стойки уже подготовленному клиенту, в секундах.
@export_range(0.0, 10.0) var service_transfer_pause: float = 1.0
## Скорость подготовленного получателя по свободному проходу; голод и груз по-прежнему влияют.
@export_range(1.0, 6.0) var service_approach_speed: float = 3.2
## Цепь ПВЗ, мерцающая при предупреждении светобоязненного получателя.
@export var service_light_circuit: StringName = &"warehouse"
## Длительность единственного мерцания при подходе, в секундах.
@export_range(0.1, 10.0) var service_flicker_seconds: float = 3.0
## Нижняя граница ежедневного числа предложений терминала; 0 отключает минимум.
@export_range(0, 3) var terminal_delivery_minimum: int = 1
## Верхняя граница ежедневного числа предложений терминала.
@export_range(0, 3) var terminal_delivery_maximum: int = 3
## Фиксированная доплата терминала; -1 означает базовую оплату выдачи.
@export_range(-1, 10000) var terminal_delivery_bonus: int = -1
## Вероятность личного предложения для подходящего местного получателя.
@export_range(0.0, 1.0) var personal_delivery_probability: float = 0.10
## Тестовый минимум личных предложений в день; 0 оставляет только вероятность.
@export_range(0, 1) var personal_delivery_daily_minimum: int = 1
## Шанс согласия на однократную просьбу повысить доплату.
@export_range(0.0, 1.0) var delivery_bargain_probability: float = 0.50
## Согласованная доплата в процентах от исходной; 150 означает +50%.
@export_range(100, 300) var delivery_bargain_percent: int = 150
## Допустимый урон обычного маршрута как доля полного здоровья.
@export_range(0.0, 1.0) var ordinary_route_risk: float = 0.05

## Множитель слышимости через физические препятствия.
@export_range(0.0, 1.0) var hearing_wall_attenuation: float = 0.25
## Интервал событий шагов, в секундах.
@export_range(0.1, 2.0) var footstep_interval: float = 0.6
## Радиус звука ходьбы, в метрах.
@export_range(0.1, 30.0) var walking_noise_radius: float = 6.0
## Радиус звука бега, в метрах.
@export_range(0.1, 40.0) var running_noise_radius: float = 12.0
## Открытие двери и подбор предмета слышны в этом радиусе, в метрах.
@export_range(0.1, 30.0) var interaction_noise_radius: float = 4.0
## Попытка удара слышна в этом радиусе, даже если удар не попал.
@export_range(0.1, 40.0) var strike_noise_radius: float = 10.0
## Реальный урон создаёт слышимый удар или крик боли.
@export_range(0.1, 40.0) var damage_noise_radius: float = 14.0
## Множитель громкости движения в приседе.
@export_range(0.0, 1.0) var crouching_noise_fraction: float = 0.3

#region Place queries
## Находит авторское место по постоянному ID.
func place_for(place_key: StringName) -> DEF_DistrictPlace:
	for place: DEF_DistrictPlace in places:
		if place != null and place.key == place_key:
			return place
	return null
#endregion
