extends GameDefinition
## Личность, характер и способности; правила обслуживания принадлежат каждому заказу.
class_name DEF_NpcProfile

## Способности ближнего боя для существующего исполнителя атак.
@export var melee_attacks: Array[DEF_NpcAttack] = [preload("res://content/definitions/gameplay/combat/def_npc_punch.tres")]
## Способности дальнего боя; у обычных жителей список пуст.
@export var ranged_attacks: Array[DEF_NpcAttack] = []

enum Personality { AGGRESSIVE, BRAZEN, CHEERFUL, TIMID }

## Имя в диалоге и над физическим телом.
@export var display_name: String = "Житель"
## Личность занимает дом в этом районе.
@export var resident: bool = true
## Местный житель обслуживает существующий торговый ассортимент.
@export var merchant: bool = false
## Ключ получателя используется только при создании новых поставок.
@export var recipient_key: StringName = &""
## Основной характер для социальных реакций.
@export var personality: Personality = Personality.CHEERFUL
## Цели фаз недельного расписания.
@export var schedule: DEF_NpcSchedule = null
## Не более двух совместимых сверхъестественных особенностей.
@export var rules: Array[DEF_NpcTrait] = []
## Внешняя сцена физического тела этой личности.
@export_file("*.tscn") var npc_scene_path: String = "res://content/entities/npc/district_npc.tscn"
## Личные интересы для уличных разговоров.
@export var interests: PackedStringArray = []
## Предпочитаемые занятия; допустимое место выбирается детерминированно.
@export var preferred_activities: PackedInt32Array = [0, 1, 2, 3]
## Наблюдаемая скорость отступления из текущего столкновения.
@export_range(0.1, 8.0) var retreat_speed: float = 1.5
## Время видимого отступления до фиксации подчинения, в секундах.
@export_range(0.2, 5.0) var retreat_seconds: float = 0.8
## Вероятность резкой реакции на подтверждённую провинность.
@export_range(0.0, 1.0) var high_attack_probability: float = 0.75
## Вероятность бегства для агрессивного и борзого характера.
@export_range(0.0, 1.0) var low_flee_probability: float = 0.1
## Вероятность спокойно принять шутку для весёлого характера.
@export_range(0.0, 1.0) var joke_acceptance_probability: float = 0.9
## Вероятность бегства трусливого NPC при серьёзной угрозе.
@export_range(0.0, 1.0) var timid_flee_probability: float = 0.8
## Вероятность нападения трусливого NPC при серьёзной угрозе.
@export_range(0.0, 1.0) var timid_attack_probability: float = 0.05
## Скорость ходьбы по земле, в метрах в секунду.
@export_range(0.1, 8.0) var move_speed: float = 1.8
## Близкое распознавание также требует прямой физической видимости.
@export_range(0.2, 4.0) var near_recognition_range: float = 1.5
## Максимальный радиус слуха этого NPC, в метрах.
@export_range(1.0, 50.0) var hearing_range: float = 20.0
## Дальность зрения при обычном освещении, в метрах.
@export_range(1.0, 50.0) var vision_range: float = 16.0
## Горизонтальный сектор зрения, в градусах.
@export_range(30.0, 180.0) var vision_angle: float = 110.0
## Множитель дальности обычного зрения в темноте.
@export_range(0.0, 1.0) var dark_vision_fraction: float = 0.15
## Длительность поиска после последнего подтверждённого наблюдения, в секундах.
@export_range(1.0, 120.0) var search_seconds: float = 12.0
## Последняя видимая позиция и ограниченное число проверок ближайших укрытий.
@export_range(1, 8) var search_point_count: int = 3
## Минимальная доля здоровья, которую должно оставить опасное преследование.
@export_range(0.0, 1.0) var pursuit_health_reserve: float = 0.35
## Профиль может начинать самостоятельные нападения в пределах лимита.
@export var initiates_conflicts: bool = false
## Основной цвет, различающий жителей в блокинге.
@export var body_color: Color = Color(0.65, 0.45, 0.35)

#region Trait queries
## Находит правило нечисти без создания новой коллекции.
func rule_for(kind: DEF_NpcTrait.Kind) -> DEF_NpcTrait:
	for rule: DEF_NpcTrait in rules:
		if rule != null and rule.kind == kind:
			return rule
	return null

## Проверяет совместимость авторских особенностей перед появлением NPC.
func valid_rules() -> bool:
	if rules.size() > 2:
		return false

	var seen: Array[int] = []
	for rule: DEF_NpcTrait in rules:
		if rule == null or seen.has(rule.kind):
			return false

		for other: DEF_NpcTrait in rules:
			if other != null and other != rule and rule.incompatible.has(other.kind):
				return false

		seen.append(rule.kind)
	return schedule != null
#endregion
