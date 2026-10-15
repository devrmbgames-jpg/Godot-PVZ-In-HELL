extends Component
## Чернила одной коробки; сохранение привязывает их к постоянному package_id.
class_name C_PackageMarks

## Упорядоченные локальные штрихи, независимые от регистрации и размещения на полке.
var strokes: Array[PackageMarkStroke] = []
## Производное число точек: PackageMarkService обновляет при рисовании/очистке.
## WorldSnapshotService пересчитывает при load.
var point_count: int = 0
## Revision для перестройки mesh; увеличивают PackageMarkService и явное восстановление чернил.
var revision: int = 0
