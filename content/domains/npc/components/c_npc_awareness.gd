extends Component
## Derived восприятие/поиск S_NpcPerception, реакции S_NpcTraits и явных Services/BT leaves.
## Все накопители — GamePlay seconds; due stages получают общий scheduled_delta S_NpcCadence.
## Живого противника связывают Relationships; reset очищает этот Component без замены личности.
class_name C_NpcAwareness

## Transient rejected navigation targets; cleared on reconstruction and when a zone expires.
var rejected_blood_ids: Array[String] = []

## Due-step authored exposure at the actor; S_NpcTraits samples it for typed darkness hunting.
var self_light_exposure: float = 1.0
## Exposure at the currently perceived player; hidden positions are never sampled.
var player_light_exposure: float = 1.0
## S_NpcTraits derives the typed predator's light constraint; combat reads it between BT updates.
var darkness_combat_suppressed: bool = false

## Связанный противник виден в текущем обновлении зрения.
var target_visible: bool = false
## Игрок виден в текущем обновлении зрения.
var player_visible: bool = false
## Последняя видимая мировая позиция противника, в метрах; скрытая текущая позиция не считывается.
var last_seen_position: Vector3 = Vector3.ZERO
## Признак подтверждённой позиции противника в прошлом.
var has_last_seen: bool = false
## Время с последнего подтверждённого наблюдения противника.
var search_elapsed: float = 0.0
## Последняя слышимая мировая позиция, в метрах, без предположения о личности источника.
var heard_position: Vector3 = Vector3.ZERO
## Оставшееся время проверки нераспознанного звука.
var heard_remaining: float = 0.0
## Последний услышанный звук является поводом прервать свободное занятие для проверки места.
var investigate_noise: bool = false
## Текущая реакция требует бегства.
var fleeing: bool = false
## Выбранный проход текущего бегства; сохраняется до выхода, чтобы маршрут не переключался у цели.
var flee_portal_id: StringName = &""
## Длительность видимого отступления игрока из текущего столкновения.
var retreat_elapsed: float = 0.0
## S_NpcDecision накапливает время простоя; лист выбора занятия сбрасывает его после выбора.
var idle_elapsed: float = 0.0
## Последний обработанный номер звука; одно событие не продлевает поиск повторно.
var last_noise_sequence: int = 0
## S_NpcFootsteps накапливает только время движения выбранного due NPC, сбрасывает при шуме.
var footstep_elapsed: float = 0.0
## Накопленное воздействие каждого правила нечисти.
var rule_exposure: Dictionary[int, float] = { }
## S_NpcTraits фиксирует предупреждения; планирование новой фазы и reset очищают список.
var warned_rules: Array[int] = []
## S_NpcTraits фиксирует реакции; планирование новой фазы и reset очищают список.
var reacted_rules: Array[int] = []
## bt_npc_search вычисляет индекс укрытия из search_elapsed и авторской длительности поиска.
var search_index: int = 0
## Дискомфорт от света запрашивает укрытие через ветку аварийного отхода.
var light_distress: bool = false

## Непосредственная опасность требует выхода из текущего объёма.
var hazard_distress: bool = false

## Оклик возможен один раз за фазу; окно диалога требует взаимодействия игрока.
var called_out: bool = false


#region Transient state reset
## Clears derived state in place; retains the constructed Component and durable NPC authority.
func reset_transient_state() -> void:
	rejected_blood_ids.clear()
	self_light_exposure = 1.0
	player_light_exposure = 1.0
	darkness_combat_suppressed = false
	target_visible = false
	player_visible = false
	last_seen_position = Vector3.ZERO
	has_last_seen = false
	search_elapsed = 0.0
	heard_position = Vector3.ZERO
	heard_remaining = 0.0
	investigate_noise = false
	fleeing = false
	flee_portal_id = &""
	retreat_elapsed = 0.0
	idle_elapsed = 0.0
	last_noise_sequence = 0
	footstep_elapsed = 0.0
	rule_exposure.clear()
	warned_rules.clear()
	reacted_rules.clear()
	search_index = 0
	light_distress = false
	hazard_distress = false
	called_out = false
#endregion
