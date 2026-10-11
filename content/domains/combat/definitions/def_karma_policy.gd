@tool
extends GameDefinition
## Authored player alignment bounds and supernatural receiver thresholds.
class_name DEF_KarmaPolicy

## Minimum legal persistent alignment value.
@export var minimum_value: float = -100.0
## Maximum legal persistent alignment value.
@export var maximum_value: float = 100.0
## Holy effects may harm the player strictly below this value.
@export var low_threshold: float = -25.0
## Unholy effects may harm the player strictly above this value.
@export var high_threshold: float = 25.0
