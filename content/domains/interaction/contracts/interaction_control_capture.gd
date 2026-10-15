extends RefCounted
## Запись независимого захвата ввода со слабой ссылкой владельца и приоритетом.
class_name InteractionControlCapture

## WeakRef владельца; InteractionControlFocus.current лениво удаляет запись после его исчезновения.
var owner: WeakRef = null
## Приоритет из InteractionControlFocus.Priority; больший уровень подавляет меньший.
var priority: int = 0
