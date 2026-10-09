extends Resource
## Личность и история фаз; здоровье и предметы остаются на физическом теле.
class_name NpcRecord

enum Placement { STREET, HOME, OUTSIDE, DEAD }

## ID личности на всю жизнь, независимо от заказов и дат визита.
@export var npc_id: StringName = &""
## Ссылка на авторский профиль личности.
@export var profile: DEF_NpcProfile = null
## Постоянное имя, включая имя новой личности при заселении.
@export var display_name: String = ""
## Получатель новых поставок по адресу; старые заказы не переназначаются.
@export var recipient_key: StringName = &""
## Постоянный домашний адрес; пуст у приезжих.
@export var home_id: StringName = &""
## Текущее размещение личности: улица, дом, вне района или смерть.
@export var placement: Placement = Placement.HOME
## Закреплённая точка входа и выхода из района.
@export var portal_id: StringName = &""
## Другая точка выхода для приезжего, проходящего район насквозь.
@export var exit_id: StringName = &""
## Авторское место обязательной цели фазы.
@export var goal_id: StringName = &""
## Последний зафиксированный день расписания.
@export var planned_day: int = 0
## Последняя зафиксированная фаза расписания.
@export var planned_phase: int = -1
## Обязательная задача текущей фазы завершена.
@export var phase_complete: bool = false
## Воспринятые личностью социальные инциденты.
@export var memories: Array[NpcMemory] = []
## День окончательной смерти; у живой личности равен нулю.
@export var death_day: int = 0
## Последовательность занятий сохраняет выбор при перезагрузке.
@export var activity_sequence: int = 0

#region Durable AI cadence
## Last elapsed clock timestamp sampled by S_NpcCadence; -1 before first participation.
@export var cadence_sample_tick: int = -1
## Retained active AI interval in microsecond ticks; S_NpcCadence owns accumulation/consumption.
@export var cadence_elapsed_ticks: int = 0
#endregion
