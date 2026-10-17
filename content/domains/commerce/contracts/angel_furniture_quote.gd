extends RefCounted
## Неплатящее предложение точному участнику/терминалу, живущее до явного подтверждения.
class_name AngelFurnitureQuote

## Точный World запроса, сохранённый без владения его жизнью.
var world: WeakRef
## Точный физический участник, без возможности подтвердить за другого.
var actor: WeakRef
## Точная native точка, а не замена с тем же ID.
var terminal: WeakRef
## Захваченная incarnation владельца истории.
var state: C_AngelOrders
## Неоплаченные либо принятые факты предложения, принадлежащие этому запросу.
var order: AngelFurnitureOrder
## Пояснение отказа; непустое предложение не оплачивается.
var reason: String = ""
