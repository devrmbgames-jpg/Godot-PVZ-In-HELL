extends Resource
## Одна принятая партия: весь расход, распознавание, подарки и обещанные результаты.
class_name CraftingBatch

## Закрытая восстанавливаемая история без live Entity ссылок.
const SAVE_FIELDS: Array[String] = [
	"operation_id",
	"container_id",
	"profile",
	"signature",
	"accepted_day",
	"ready_day",
	"inputs",
	"recipes",
	"gifts",
	"outputs",
	"trash_definition",
	"trash_quantity",
	"hint_text",
	"first_failure",
	"consumed",
	"completed",
]

## Единственный ID явного подтверждения.
@export var operation_id: StringName = &""
## Точный стабильный ID native точки; новая коробка не переназначает принятые обещания.
@export var container_id: String = ""
## Авторская личность/точка; её текущий каталог применяется только к новым передачам.
@export var profile: DEF_CraftingProfile = null
## Подписанный состав/день/профиль/состояние льготы из принятого предложения.
@export var signature: String = ""
## Фактический день приёма, без привязки к следующей жизни изготовителя.
@export var accepted_day: int = 0
## Обещанный календарный день, всегда accepted_day + 1.
@export var ready_day: int = 0
## Полные физические стеки, все забираются однократно, включая подарки.
@export var inputs: Array[CraftingInput] = []
## Зафиксированные шаги расхода/результата; один рецепт может встретиться несколько раз.
@export var recipes: Array[CraftingStep] = []
## Неиспользованные количества — подарок; не выдаются и не оплачиваются.
@export var gifts: Array[CraftingInput] = []
## Изделия или authored мусор; первая неудача оставляет этот массив пустым.
@export var outputs: Array[CraftingOutput] = []
## Принятый тип мусора поздней неудачи; у успеха и первой подсказки null.
@export var trash_definition: DEF_InventoryItem = null
## Принятое число единиц мусора; ноль у успеха и первой подсказки.
@export var trash_quantity: int = 0
## Дословное обещание первой подсказки; смена каталога не переписывает надпись.
@export var hint_text: String = ""
## Эта непустая неудача использовала единственную кампанийную льготу.
@export var first_failure: bool = false
## Все принятые физические endpoints выбыли под transaction guard.
@export var consumed: bool = false
## Выданы и забраны все результаты либо утром опубликована первая подсказка.
@export var completed: bool = false
