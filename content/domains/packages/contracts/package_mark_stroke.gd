extends RefCounted
## Непрерывный штрих на одной грани коробки, целиком в её локальных координатах.
class_name PackageMarkStroke

## Точки штриха в локальных координатах; мировая позиция не сохраняется.
var points: PackedVector3Array = PackedVector3Array()
## Наружная нормаль грани в локальных координатах коробки.
var normal: Vector3 = Vector3.UP
## Толщина линии в метрах, скопированная с маркера при начале штриха.
var width: float = 0.012
## Цвет чернил, скопированный при начале штриха.
var color: Color = Color.BLACK
