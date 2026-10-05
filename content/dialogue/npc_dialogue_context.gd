extends RefCounted
## Общий интерфейс UI; уличный и клиентский контексты обращаются к своим сервисам.
class_name NpcDialogueContext

var _delivery_job_id: StringName = &""
#region Интерфейс контекста
func _init(_actor: Entity = null, _interlocutor: Entity = null) -> void:
	pass

## Начинает конкретное взаимодействие после проверки условий.
func begin() -> bool:
	return false

## Освобождает участников, не владея модальным захватом ввода.
func end() -> void:
	pass

## Проверяет текущих участников и условия предметной области.
func is_valid() -> bool:
	return false

## Проверяет возможность продолжения диалогового UI.
func can_continue() -> bool:
	return false

## Сохраняет авторский текст, пока конкретный адаптер не изменяет восприятие игрока.
func perceived_text(actual_text: String) -> String:
	return actual_text

## Применяет смысл ответа через конкретный игровой адаптер.
func apply_response_tags(_tags: PackedStringArray) -> bool:
	return false

## Проверяет, относится ли открытый UI к этому NPC, без создания новой живой связи.
func speaks_with(_npc: Entity) -> bool:
	return false
#endregion

#region Личное предложение и торг
## Конкретный адаптер проверяет пригодность личного заказа.
func can_offer_delivery() -> bool:
	return false

## Читает сохранённый адрес, не публикуя его системе терминала.
func delivery_address() -> String:
	var job: NpcHomeDelivery = _delivery_record()
	return DistrictPopulationService.place_name(job.address_id) if job != null else ""

## Читает текущую согласованную доплату.
func delivery_bonus() -> int:
	var job: NpcHomeDelivery = _delivery_record()
	return job.bonus if job != null else 0

## Читает сумму однократного запроса торга, по умолчанию +50%.
func requested_delivery_bonus() -> int:
	var job: NpcHomeDelivery = _delivery_record()
	var district: C_District = DistrictPopulationService.current()
	return floori(float(job.base_bonus) * district.definition.delivery_bargain_percent / NpcDeliveryOfferService.PERCENT_SCALE) if job != null and district != null else 0

## Вариант торга исчезает после сохранённого ответа NPC.
func can_bargain_delivery() -> bool:
	var job: NpcHomeDelivery = _delivery_record()
	return can_offer_delivery() and job != null and job.bargain == NpcHomeDelivery.Bargain.NONE

## Запрашивает один сохранённый ответ на повышение доплаты.
func negotiate_home_delivery() -> bool:
	var job: NpcHomeDelivery = _delivery_record()
	return is_valid() and job != null and NpcDeliveryOfferService.negotiate(job.job_id) != NpcHomeDelivery.Bargain.NONE

## Позволяет авторской ветке показать согласие или отказ без повторного броска.
func delivery_bargain_accepted() -> bool:
	var job: NpcHomeDelivery = _delivery_record()
	return job != null and job.bargain == NpcHomeDelivery.Bargain.ACCEPTED

## Передаёт только авторское предупреждение, а не скрытый итог сценария.
func delivery_hint() -> String:
	var scenario: DEF_NpcDeliveryScenario = NpcDeliveryScenarioService.definition_for(_delivery_record())
	return scenario.offer_hint if scenario != null else ""

## Выделяет личное незавершённое последствие предыдущего обещания.
func has_broken_promise() -> bool:
	return NpcSocialService.pending_promise(_delivery_npc()) != null

## Применяет зафиксированную реакцию характера через сервис при следующем разговоре.
func resolve_broken_promise() -> bool:
	return NpcSocialService.resolve_promise(_delivery_npc(), _delivery_player())

func _delivery_record() -> NpcHomeDelivery:
	if not _delivery_job_id.is_empty():
		return NpcDeliveryOfferService.find(_delivery_job_id)
	var job: NpcHomeDelivery = _delivery_offer()
	if job != null:
		_delivery_job_id = job.job_id
	return job

func _delivery_offer() -> NpcHomeDelivery:
	return null

func _delivery_npc() -> E_DistrictNpc:
	return null

func _delivery_player() -> Entity:
	return null
#endregion
