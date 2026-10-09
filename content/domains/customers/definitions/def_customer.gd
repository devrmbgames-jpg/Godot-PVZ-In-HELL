extends GameDefinition
## Политика обслуживания заказа; постоянная личность и её природа задаются отдельно в DEF_NpcProfile.
class_name DEF_Customer

enum DialogueMode { DIRECT, RIDDLE }
enum Introduction { MANUAL, ANNOUNCE_ORDER, FIRST_APPROACH_DIALOGUE }
const MINIMUM_LEAVING_SECONDS: float = 181.0

#region Представление и взаимодействие
## Имя обычного клиента; у жителей района отображается имя постоянной личности.
@export var display_name: String = "Клиент"
## Сцена обычного клиента; пустое значение использует общую сцену расписания.
@export_file("*.tscn") var customer_scene_path: String = ""
## Пользовательский диалог обслуживания; пустое значение выбирает стандартный ресурс.
@export_file("*.dialogue") var dialogue_resource_path: String = ""
## Авторские интересы для контекста диалога обычного клиента, без скрытой шкалы.
@export var interests: PackedStringArray = []
## Получатель допускает повреждённую коробку при обычной проверке выдачи.
@export var accepts_damaged: bool = true
## Получатель допускает уже вскрытую коробку.
@export var accepts_opened: bool = true
## Получатель добровольно отказывается от подходящей коробки.
@export var voluntary_refusal: bool = false
## Локальное смещение оставленной коробки, принятой непосредственно из рук игрока, в метрах.
@export var refused_parcel_offset: Vector3 = Vector3(0.75, 0.75, 0.0)
## Режим сообщения заказа обычного клиента; особенности жителя имеют свой приоритет.
@export var dialogue_mode: DialogueMode = DialogueMode.DIRECT
## Способ знакомства: взаимодействие, объявление номера или диалог при близком подходе.
@export var introduction: Introduction = Introduction.MANUAL
## Дистанция автоматического начала диалога при видимости и свободном вводе, в метрах.
@export_range(0.5, 5.0, 0.1) var auto_dialogue_distance: float = 2.0
## Клиент принимает свой зарегистрированный заказ из рук игрока вблизи, вне диалога.
@export var automatic_handoff: bool = true
## Дистанция автоматического получения коробки из рук, в метрах.
@export_range(0.2, 3.0, 0.1) var automatic_handoff_distance: float = 1.5
## Изменения удовлетворённости и вероятностей по смыслу ответа игрока.
@export var dialogue_reactions: Array[DEF_CustomerDialogueReaction] = []
## Сценарное испытание обычного клиента; постоянные NPC используют собственные особенности.
@export var challenge: DEF_Challenge = null
## Однократный штраф за неверный ответ на загадку, в пунктах шкалы 0–100.
@export_range(0, 100) var riddle_wrong_satisfaction_penalty: int = 20
#endregion

#region Движение и длительности
## Скорость обычного клиента, в м/с; физическое исполнение остаётся у тела.
@export var move_speed: float = 1.8
## Горизонтальный допуск прибытия к цели обслуживания, в метрах.
@export var arrival_distance: float = 0.25
## Максимальная длительность подхода до ухода, в секундах.
@export var approach_timeout: float = 120.0
## Ожидание приветствия после прибытия, в секундах.
@export var greeting_seconds: float = 8.0
## Терпение при ожидании коробки или диалоге, в секундах.
@export var patience_seconds: float = 720.0
## Пауза после фактического получения до начала ухода, в секундах.
@export var receiving_seconds: float = 4.0
#endregion

#region Частный осмотр
@export_group("Private inspection")
## Использует резервирование кабинки и физический осмотр вместо немедленной выдачи.
@export var private_inspection: bool = false
## Длительность частного осмотра, в секундах.
@export_range(0.0, 600.0, 1.0, "or_greater") var inspection_seconds: float = 12.0
## Вероятность распаковки во время осмотра, от 0 до 1.
@export_range(0.0, 1.0) var inspection_unpack_probability: float = 0.0
## Вероятность оставить себе заказ после осмотра, от 0 до 1.
@export_range(0.0, 1.0) var inspection_keep_probability: float = 1.0
#endregion

#region Завершение визита и последствия
@export_group("")
## Предельная длительность ухода, в секундах; фактическое прибытие завершает его раньше.
@export_range(181.0, 3600.0, 1.0, "or_greater") var leaving_seconds: float = MINIMUM_LEAVING_SECONDS
## Предельная длительность агрессивной фазы обслуживания, в секундах.
@export var aggressive_seconds: float = 180.0
## Старое поле сохранено для ресурсов; гравитацией физического тела владеет Godot/Jolt.
@export var gravity: float = 20.0
## Базовая удовлетворённость целой коробкой, на шкале 0–100.
@export var healthy_satisfaction: int = 100
## Верхняя граница удовлетворённости повреждённой коробкой, на шкале 0–100.
@export var damaged_satisfaction: int = 70
## Верхняя граница удовлетворённости вскрытой коробкой, на шкале 0–100.
@export var opened_satisfaction: int = 50
## Текст жалобы; пустое значение использует обычную формулировку по причине обвинения.
@export_multiline var complaint_text: String = ""
## Вероятность жалобы после отказа игрока в выдаче, от 0 до 1.
@export_range(0.0, 1.0) var complaint_probability: float = 0.85
## Вероятность жалобы при подтверждённом отказе самого получателя, от 0 до 1.
@export_range(0.0, 1.0) var voluntary_complaint_probability: float = 0.15
## Вероятность ложной жалобы после фактической выдачи, от 0 до 1.
@export_range(0.0, 1.0) var false_complaint_probability: float = 0.05
## Вероятность немедленной агрессии после отказа игрока, от 0 до 1.
@export_range(0.0, 1.0) var immediate_aggression_probability: float = 0.1
## Вероятность жалобы после нерешённого визита, от 0 до 1.
@export_range(0.0, 1.0) var unresolved_complaint_probability: float = 0.25
## Вероятность повторного визита по нерешённому заказу, от 0 до 1.
@export_range(0.0, 1.0) var followup_probability: float = 0.75
## Пауза до случайно назначенного повторного визита, в игровых днях.
@export_range(1, 30) var followup_delay_days: int = 1
## Лимит обычных повторных визитов по одному заказу.
@export_range(0, 10) var max_followup_visits: int = 2
## Пауза от подачи жалобы до рассмотрения, в игровых днях.
@export_range(1, 30) var complaint_delay_days: int = 1
## Срок разрешённого ответа игрока на ложную жалобу, в игровых днях.
@export_range(1, 30) var retaliation_days: int = 7
#endregion
