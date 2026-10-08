extends RefCounted
## Запись независимого захвата ввода со слабой ссылкой владельца и приоритетом.
class_name InteractionControlCapture

## Слабая ссылка владельца; исчезновение владельца освобождает захват.
var owner: WeakRef = null
## Приоритет из InteractionControlFocus.Priority; больший уровень подавляет меньший.
var priority: int = 0
