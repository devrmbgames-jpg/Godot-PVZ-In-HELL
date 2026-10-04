extends Resource
## Авторские пороги получателя и коэффициенты преобразования энергии столкновения.
class_name DEF_ImpactProfile

## Минимальная скорость сближения вдоль нормали в м/с.
@export_range(0.0, 50.0) var minimum_speed: float = 2.5
## Минимальный нормальный импульс контакта в Н·с.
@export_range(0.0, 1000.0) var minimum_impulse: float = 0.5
## Единицы здоровья на переданный джоуль после поглощения.
@export_range(0.0, 10.0) var damage_per_joule: float = 0.15
## Энергия в джоулях, поглощаемая без потери здоровья.
@export_range(0.0, 10000.0) var absorption_joules: float = 5.0
## Доля максимального здоровья на одно столкновение; 1.0 разрешает потерю вплоть до полного максимума.
@export_range(0.0, 1.0, 0.005) var max_hp_fraction_per_hit: float = 1.0
## Порог средней тяжести по потенциальному урону до ограничения потери HP.
@export var medium_damage: float = 8.0
## Порог сильной тяжести по потенциальному урону до ограничения HP.
@export var strong_damage: float = 30.0
