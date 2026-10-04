extends RefCounted
## Результат чистой проверки коробки; сам не выдаёт предмет и не начисляет деньги.
class_name PackageDeliveryCheck

enum Result { READY, MISSING, MULTIPLE, UNREGISTERED, WRONG_PACKAGE, UNASSIGNED, DESTROYED, HELD, ALREADY_CLOSED }

## Причина отказа в операции или READY для продолжения обычной выдачи.
var result: Result = Result.MISSING
## Коробка повреждена на момент проверки; влияет на принятие и удовлетворённость.
var damaged: bool = false
## Коробка вскрыта на момент проверки; это отдельный факт от повреждения.
var opened: bool = false
