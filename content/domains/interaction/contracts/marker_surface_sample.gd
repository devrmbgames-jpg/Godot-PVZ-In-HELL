extends RefCounted
## Проверенное попадание маркера для последующего преобразования в локальные чернила коробки.
class_name MarkerSurfaceSample

## Живая коробка, прошедшая проверки допустимости рисования.
var parcel: Entity = null
## Мировая точка физического попадания по коробке.
var world_point: Vector3 = Vector3.ZERO
## Мировая наружная нормаль поверхности попадания.
var world_normal: Vector3 = Vector3.UP
