extends Component
## Чернила одной коробки; сохранение привязывает их к постоянному package_id.
class_name C_PackageMarks

## Упорядоченные локальные штрихи, независимые от регистрации и размещения на полке.
var strokes: Array[PackageMarkStroke] = []
## Общее число точек; записывается только PackageMarkService.
var point_count: int = 0
## Версия чернил для обновления представления; меняется через PackageMarkService.
var revision: int = 0
