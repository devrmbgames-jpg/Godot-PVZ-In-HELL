@tool
extends Entity
## Авторская площадка помощи размещению Carry; занятость определяют физические проверки.
class_name E_PlacementArea

## Авторская точка начала тела; вокруг неё проверяются все реальные collision shapes предмета.
@export var anchor: Node3D = null
