extends Resource
## Адаптер разрешённых источников предметов без состояния; владение остаётся в Relationships.
class_name DEF_ItemAccessProvider


#region Контракт источника предметов
## Возвращает доступные конкретные предметы актора; базовый адаптер не предоставляет предметов.
func items(_actor: Entity) -> Array[Entity]:
	return []


## Проверяет возможность расходования предмета; базовый адаптер запрещает её.
func can_consume(_actor: Entity, _item: Entity) -> bool:
	return false


## Повторно проверяет владение перед расходованием; при отказе не изменяет мир.
func consume(_actor: Entity, _item: Entity) -> bool:
	return false

#endregion
