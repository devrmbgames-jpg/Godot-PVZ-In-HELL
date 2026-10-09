extends GameDefinition
## Дроп архетипа NPC; сцены должны быть физическими Entity с корректным C_InventoryItem.
class_name DEF_NpcRemains

const MAX_MEAT_PIECES: int = 12

## Физическая сцена одного куска мяса с C_InventoryItem.
@export var meat_scene: PackedScene = null
## Количество отдельных кусков мяса; проверяется сервисом до создания партии.
@export_range(1, MAX_MEAT_PIECES, 1) var meat_piece_count: int = 3
## Радиус размещения кусков вокруг тела в метрах.
@export_range(0.2, 2.0, 0.05) var piece_spacing: float = 0.45
## Необязательная физическая сцена дополнительного предмета.
@export var loot_scene: PackedScene = null
## Вероятность дополнительного предмета 0–1; бросок воспроизводим по ID Entity.
@export_range(0.0, 1.0, 0.01) var loot_chance: float = 0.25
