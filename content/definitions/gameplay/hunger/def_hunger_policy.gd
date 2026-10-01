extends GameDefinition
class_name DEF_HungerPolicy

@export var maximum: float = 100.0
@export var hungry_threshold: float = 40.0
@export var starving_threshold: float = 75.0
@export var growth_per_second: float = 0.2
@export var hungry_speed_multiplier: float = 1.15
@export var starving_speed_multiplier: float = 1.35
@export var hungry_damage_multiplier: float = 1.2
@export var starving_damage_multiplier: float = 1.5
