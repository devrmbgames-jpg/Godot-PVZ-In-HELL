extends Resource
## Постоянный журнал заказа без ссылок на Entity; назначение живой коробки хранит R_AssignedTo.
class_name CustomerVisit

enum Actual { NOT_RESOLVED, DELIVERED, CUSTOMER_REFUSED, PLAYER_DENIED }
enum Declaration { NONE, TAKEN, REFUSED, LOST }
enum LossCause { NONE, DECLARED_LOST, MISSED_REGISTRATION }
enum Disposition { WAREHOUSE, DELIVERED, RETURNED, BOUGHT_OUT, LOST }
enum Reputation {
	NONE,
	PLAYER_DENIAL,
	LOST,
	CONFIRMED_REFUSAL,
	FRAUD,
	FALSE_COMPLAINT,
	DAMAGED_COMPLAINT,
}
enum Feedback { NONE, APPROVED }

#region Личность и коробка
## ID конкретного заказа, сохраняемый при повторных визитах и домашней доставке.
@export var visit_id: StringName = &""
## ID получателя; в районе это постоянный npc_id, независимый от даты поставки.
@export var customer_id: StringName = &""
## ID физической коробки, отдельно от видимого регистрационного номера.
@export var package_id: String = ""
## Скрытый ID складской истории; не показывается как номер заказа получателя.
@export var package_history_id: String = ""
## Задача получения разрешается только после регистрации коробки.
@export var requires_registered_package: bool = true
## Самый ранний игровой день самостоятельного появления по этому заказу.
@export var arrival_day: int = 1
## Авторские правила приёма, удовлетворённости и последствий обслуживания.
@export var definition: DEF_Customer = null
## Учётная стоимость заказа для денежных последствий, в валюте игры.
@export var accounting_value: int = 0
## Базовая оплата выдачи до поправки удовлетворённости, в валюте игры.
@export var payment: int = 0
#endregion

#region Факты обслуживания
## Что реально произошло с получением; не подменяется заявлением в терминале.
@export var actual: Actual = Actual.NOT_RESOLVED
## Заявленный игроком результат учёта: забрано, отказ или потеря.
@export var declaration: Declaration = Declaration.NONE
## Причина LOST: заявление игрока либо пропущенная регистрация следующего утра.
@export var loss_cause: LossCause = LossCause.NONE
## Текущий складской итог: хранится, выдано, возвращено, выкуплено или потеряно.
@export var disposition: Disposition = Disposition.WAREHOUSE
## Репутационный результат этого случая для отчёта и последствий.
@export var reputation: Reputation = Reputation.NONE
## Итоговая удовлетворённость, ограниченная шкалой 0–100.
@export var satisfaction: int = 0
#endregion

#region Диалог и испытания
## Накопленная добавка удовлетворённости от смысловых ответов игрока.
@export var dialogue_satisfaction_delta: int = 0
## Накопленная добавка удовлетворённости от разрешённых испытаний.
@export var challenge_satisfaction_delta: int = 0
## Номер визита последнего применённого испытания; -1 означает отсутствие результата.
@export var challenge_visit_count: int = -1
## Ключ последнего применённого испытания; вместе с номером визита защищает от повтора.
@export var challenge_key: StringName = &""
## Стабильный ключ последнего результата испытания для отчёта и диалога.
@export var challenge_result: StringName = &""
## Последний применённый смысл ответа, независимо от текста реплики.
@export var last_dialogue_intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.Type.NONE
## Битовая маска применённых намерений; одна и та же реакция не начисляется повторно.
@export var applied_dialogue_intents: int = 0
## Накопленная добавка к вероятности жалобы; итог ограничивается 0–1.
@export var complaint_probability_delta: float = 0.0
## Накопленная добавка к вероятности агрессии; итог ограничивается 0–1.
@export var aggression_probability_delta: float = 0.0
## Накопленная добавка к вероятности повторного визита; итог ограничивается 0–1.
@export var followup_probability_delta: float = 0.0
## Однократный штраф за неверный ответ на загадку уже применён.
@export var riddle_wrong_answer_applied: bool = false
## Загадка этого заказа решена; повторный разговор не требует нового ответа.
@export var riddle_solved: bool = false
## Явное одобрение игроком результата обслуживания.
@export var feedback: Feedback = Feedback.NONE
#endregion

#region История визитов
## Зафиксированное повреждение при получении для последующего рассмотрения жалобы.
@export var package_damaged: bool = false
## Зафиксированное вскрытие при получении, сохраняемое после удаления коробки.
@export var package_opened: bool = false
## Текущее физическое появление назначено получателю.
@export var started: bool = false
## Текущее появление завершено; нерешённый заказ может иметь повторный визит.
@export var finished: bool = false
## День завершения текущего появления; при реактивации сбрасывается.
@export var finished_day: int = 0
## Количество реальных появлений по этому заказу, включая встречу у двери.
@export var visit_count: int = 0
## Возрастающий номер появления для порядка очереди района.
@export var queue_order: int = 0
## Число назначенных обычных повторных визитов по нерешённому заказу.
@export var followup_count: int = 0
## День следующего согласованного визита; ноль означает отсутствие назначения.
@export var next_followup_day: int = 0
## Повторный визит уже согласован; завершение появления не бросает жалобу вместо договорённости.
@export var followup_committed: bool = false
## Отказ от предложения домашней доставки; повторный разговор не предлагает её снова.
@export var home_delivery_declined: bool = false
## День последнего реального появления этого получателя по заказу.
@export var last_visit_day: int = 0
## Число фактических отказов игрока в выдаче.
@export var player_denial_count: int = 0
#endregion

#region Смерть, расчёт и жалоба
## Получатель окончательно погиб; заказ не переносится новой личности.
@export var customer_dead: bool = false
## Последняя смертельная причина связывает поражение получателя с игроком.
@export var defeated_by_player: bool = false
## Денежный расчёт заказа уже зафиксирован; повтор не создаёт новую операцию.
@export var settlement_committed: bool = false
## День подтверждённого расчёта заказа.
@export var settlement_day: int = 0
## Денежный итог обычного расчёта со знаком для отчёта, в валюте игры.
@export var money_delta: int = 0
## Постоянный бросок жалобы в диапазоне 0–1; не меняется при повторном открытии диалога.
@export var complaint_roll: float = 1.0
## Постоянный бросок агрессии в диапазоне 0–1.
@export var aggression_roll: float = 1.0
## Последствия обслуживания требуют агрессивной фазы.
@export var aggressive: bool = false
## Единственная постоянная жалоба этого заказа либо null.
@export var complaint: CustomerComplaint = null
## Последний зафиксированный боевой контекст для рассмотрения последствий и UI.
@export var last_combat_context: CombatContext = null
#endregion
