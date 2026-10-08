extends RefCounted
## Жизненный цикл пары в World: одно разрешение контакта до физического разделения.
class_name ImpactContactPair

## Первое тело пары; запись не владеет Node, его доступность проверяется при обработке.
var first: PhysicsBody3D = null
## Второе тело пары; запись не владеет Node.
var second: PhysicsBody3D = null
## Эпизод контакта уже разрешён; повтор блокируется до разделения.
var resolved: bool = false
## Такт разделения не позволяет запоздавшему снимку открыть новый эпизод.
var separated_tick: int = -1
