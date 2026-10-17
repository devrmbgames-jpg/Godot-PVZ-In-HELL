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
	"first_failure",
	"consumed",
	"completed",
]

## Единственный ID явного подтверждения.
@export var operation_id: StringName = &""
## Точный стабильный ID native точки; новая коробка не переназначает принятые обещания.
@export var container_id: String = ""
## Неизменяемые рецепты/личность, по которым принята партия.
@export var profile: DEF_CraftingProfile = null
## Подписанный состав/день/профиль/состояние льготы из принятого предложения.
@export var signature: String = ""
## Фактический день приёма, без привязки к следующей жизни изготовителя.
@export var accepted_day: int = 0
## Обещанный календарный день, всегда accepted_day + 1.
@export var ready_day: int = 0
## Полные физические стеки, все забираются однократно, включая подарки.
@export var inputs: Array[CraftingInput] = []
## Порядок выбранных полных рецептов; один рецепт может встретиться несколько раз.
@export var recipes: Array[DEF_CraftingRecipe] = []
## Неиспользованные количества — подарок; не выдаются и не оплачиваются.
@export var gifts: Array[CraftingInput] = []
## Изделия или authored мусор; первая неудача оставляет этот массив пустым.
@export var outputs: Array[CraftingOutput] = []
## Эта непустая неудача использовала единственную кампанийную льготу.
@export var first_failure: bool = false
## Все принятые физические endpoints выбыли под transaction guard.
@export var consumed: bool = false
## Выданы и забраны все результаты либо утром опубликована первая подсказка.
@export var completed: bool = false
