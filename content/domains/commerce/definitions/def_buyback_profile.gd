@tool
extends GameDefinition
## Авторская скупка конкретного соседа; каталог его продаж остаётся отдельным контрактом.
class_name DEF_BuybackProfile

enum Pricing {
	DEMON_DAILY,
	FIXED,
}

## Обратимый технический ассортимент; true не объявляет цены и персонажа финальным каноном.
@export var prototype: bool = true
## Постоянный ID покупателя из authored roster; живую связь разрешает commerce query.
@export var npc_id: StringName = &""
## Имя точки для контейнера и подтверждения, без скрытых игровых фактов.
@export var display_name: String = "Скупка"
## Дьявол использует утверждённые 30–70% и дневной спрос; FIXED — явную таблицу ниже.
@export var pricing: Pricing = Pricing.DEMON_DAILY
## Битовая маска фаз; техническая NIGHT всегда закрыта.
@export_flags("Morning:1", "Day:2", "Evening:4") var open_phases: int = 1
## Явные запрещённые item IDs, включая авторское сопоставление святого символа.
@export var rejected_item_keys: PackedStringArray = []
## Только FIXED: item key → целая закупочная цена единицы; неизвестные позиции не принимаются.
@export var fixed_prices: Dictionary[StringName, int] = { }
