extends GameDefinition
## Авторское определение посылки, её физических параметров, содержимого и последствий состояния.
class_name DEF_Package

const MAX_CONTENT_QUANTITY: int = 99

enum Tag {
	NORMAL = 1,
	FRAGILE = 2,
	HEAVY = 4,
	LIQUID = 8,
}

## Диагностический класс, закодированный в скрытом ID истории.
## Не заменяет игровые теги и сцены опасностей.
enum HazardClass {
	NORMAL,
	FRAGILE,
	LIQUID,
	TOXIC,
	EXPLOSIVE,
	OTHER,
}

#region Стоимость и содержимое
## Учётная стоимость в целых денежных единицах, независимая от цены у торговца.
@export_range(0, 1000000000) var accounting_value: int = 100
## Ключ содержимого в ассортименте, используемый для оценки стоимости.
@export var content_item_key: StringName = &""
## Количество единиц содержимого для оценки, 1–99.
@export_range(1, MAX_CONTENT_QUANTITY) var content_quantity: int = 1
## Необязательная сцена реального извлекаемого содержимого.
@export var unpack_scene: PackedScene = null
## Смещение содержимого от коробки до проекции на реальную опорную геометрию.
@export var unpack_offset: Vector3 = Vector3(2.0, 0.0, 0.0)
## Мелкое содержимое выбрасывается над коробкой; мебель размещается на опоре.
@export var spill_contents: bool = true
## Скорость разлёта извлечённого содержимого в метрах в секунду.
@export_range(0.0, 5.0, 0.1) var spill_speed: float = 1.2
## Активировать опасность на реально созданном содержимом.
@export var activate_contents_hazard: bool = false
## Масса пустой коробки после извлечения, в килограммах.
@export_range(0.1, 10.0, 0.1) var empty_mass_kg: float = 1.0
#endregion

#region Отправление и физические параметры
## Авторский номер отправления в описании; не является складским номером выдачи.
@export var shipment_number: String = ""
## Описание посылки для представления игроку.
@export_multiline var description: String = ""
## Авторский комментарий к отправлению.
@export_multiline var comment: String = ""
## Постоянный ключ получателя; живая связь с клиентом создаётся через R_AssignedTo.
@export var recipient_id: StringName = &""
## Битовая маска игровых признаков Normal, Fragile, Heavy и Liquid.
@export_flags("Normal:1", "Fragile:2", "Heavy:4", "Liquid:8") var tags: int = Tag.NORMAL
## Диагностический класс для скрытого ID истории.
@export var history_hazard_class: HazardClass = HazardClass.NORMAL
## Исходная масса полной коробки в килограммах.
@export_range(0.1, 100.0, 0.1, "or_greater") var mass_kg: float = 5.0
## Авторская скорость броска коробки, в метрах в секунду.
@export var throw_velocity: float = 10.0
## Начальный и максимальный HP коробки при инициализации.
@export var maximum_health: float = 100.0
## Доля оставшегося максимального HP, при которой повреждение коробки становится заметным.
@export_range(0.0, 1.0, 0.05) var damaged_health_ratio: float = 0.60
## Пути физических вариантов сцены этой посылки.
@export_file_path("*.tscn") var scene_variants: Array[String] = []

## Общий профиль удара, независимый от описательных тегов и состояния коробки.
@export var impact_profile: DEF_ImpactProfile = preload(
	"res://content/domains/combat/definitions/def_impact_default.tres"
)

#endregion

#region Утечка и самостоятельные опасности
## Предельный наклон жидкой посылки в градусах; возврат в допустимое положение сбрасывает таймер.
@export_range(0.0, 180.0) var liquid_maximum_angle_degrees: float = 60.0
## Непрерывное время недопустимого наклона до утечки, в секундах.
@export_range(0.0, 30.0) var liquid_tilt_seconds: float = 8.0
## Однократный урон через Health при начале утечки; ноль оставляет только изменение состояния.
@export_range(0.0, 10000.0) var liquid_tilt_damage: float = 10.0

## Необязательные самостоятельные сцены опасностей; коробка не определяет их поведение.
## Создаётся только при первом переходе в C_PackageState.Damage.DAMAGED.
@export var hazard_on_damaged: PackedScene = null
## Создаётся при терминальном переходе в C_PackageState.Damage.DESTROYED.
@export var hazard_on_destroyed: PackedScene = null
## Необязательный эффект вскрытия, создаваемый общим эмиттером опасностей.
@export var hazard_on_opened: PackedScene = null

#endregion
