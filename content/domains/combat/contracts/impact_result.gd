extends RefCounted
## Оценка одного направления столкновения перед обычным запросом изменения здоровья.
class_name ImpactResult

const EVENT: StringName = &"physical_impact"
enum Severity {
	None,
	Weak,
	Medium,
	Strong,
}

## Настоящая повреждающая Entity; null означает физическое окружение.
var source: Entity = null
## Получатель оценённого столкновения.
var target: Entity = null
## Тяжесть потенциального удара до ограничения фактической потери HP.
var severity: Severity = Severity.None
## Расчётная сумма урона, после защиты и ограничения при дальнейшей обработке.
var amount: float = 0.0
## Переданная энергия в джоулях.
var transferred_energy: float = 0.0

## Защита получателя подавила столкновение до отправки запроса здоровья.
var protected: bool = false

## Пороги скорости/импульса пройдены, даже если поглощение обнуляет численный урон.
var qualifies: bool = false
