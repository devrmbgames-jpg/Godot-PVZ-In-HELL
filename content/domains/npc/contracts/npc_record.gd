extends Resource
## Личность и история фаз; здоровье и предметы остаются на физическом теле.
class_name NpcRecord

## Exact durable identity/variation aggregate; derived views are never serialized twice.
const SAVE_FIELDS: Array[String] = [
	"npc_id",
	"profile",
	"variation",
	"recipient_key",
	"home_id",
	"placement",
	"portal_id",
	"exit_id",
	"goal_id",
	"planned_day",
	"planned_phase",
	"phase_complete",
	"memories",
	"blood_offer_sequence",
	"blood_offers",
	"death_day",
	"activity_sequence",
	"cadence_sample_tick",
	"cadence_elapsed_ticks",
	"stalking_sequence",
	"stalking_decision_tick",
	"stalking_notice_tick",
	"stalking_next_eligible_tick",
]

enum Placement {
	STREET,
	HOME,
	OUTSIDE,
	DEAD,
}

## ID личности на всю жизнь, независимо от заказов и дат визита.
@export var npc_id: StringName = &""
## Immutable authored archetype; runtime never writes its shared tuning or trait pools.
@export var profile: DEF_NpcArchetype = null
## Committed per-person choices; creation/restore establish this before any live publication.
@export var variation: NpcVariation = null
## Read-only display view; the committed variation is the single persistent name owner.
var display_name: String:
	get:
		return variation.display_name
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
## Next never-reused personal blood confirmation; BloodConsentService is the sole gameplay writer.
@export var blood_offer_sequence: int = 1
## Personal durable blood offers/receipts; no live participant references or duplicate HP state.
@export var blood_offers: Array[BloodConsentRecord] = []
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


#region Durable stalking opportunities
## Last committed opportunity, including skipped/interrupted attempts; never reset by the brain.
@export var stalking_sequence: int = 0
## GameClock timestamp of that opportunity; -1 only before the first decision.
@export var stalking_decision_tick: int = -1
## Last successful close observation timestamp; -1 until the first episode success.
@export var stalking_notice_tick: int = -1
## Captured eligibility deadline, retained across participation/reset/load; zero before first use.
@export var stalking_next_eligible_tick: int = 0
#endregion


#region Resolved immutable capabilities
## Finds mandatory or committed optional behavior without allocating a collection or rerolling.
func rule_for(kind: DEF_NpcTrait.Kind) -> DEF_NpcTrait:
	var mandatory: DEF_NpcTrait = profile.rule_for(kind)
	if mandatory != null:
		return mandatory
	for option: DEF_NpcTraitOption in profile.optional_traits:
		if option.rule.kind == kind and variation.optional_trait_keys.has(option.rule.key):
			return option.rule
	return null


## Supplies the bounded scheduled behavior set; returned definitions remain immutable.
func rules_for() -> Array[DEF_NpcTrait]:
	return NpcVariationRules.traits_for(profile, variation)
#endregion
