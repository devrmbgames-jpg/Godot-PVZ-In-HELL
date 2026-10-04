extends GameDefinition
## Авторские границы голода и усиление скорости/атаки по порогам.
class_name DEF_HungerPolicy

## Максимальный накопленный уровень голода.
@export var maximum: float = 100.0
## Первый положительный порог усиления скорости и атаки.
@export var hungry_threshold: float = 40.0
## Второй порог выше hungry_threshold и не выше maximum.
@export var starving_threshold: float = 75.0
## Рост единиц голода за секунду активной симуляции.
@export var growth_per_second: float = 0.05
## Множитель скорости при первом пороге, не меньше 1.
@export var hungry_speed_multiplier: float = 1.15
## Множитель скорости при втором пороге, не меньше 1.
@export var starving_speed_multiplier: float = 1.35
## Множитель исходящего боевого урона при первом пороге, не меньше 1.
@export var hungry_damage_multiplier: float = 1.2
## Множитель исходящего боевого урона при втором пороге, не меньше 1.
@export var starving_damage_multiplier: float = 1.5
