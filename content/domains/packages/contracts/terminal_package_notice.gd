extends RefCounted
## Временная сводка непрочитанных известных событий одной истории посылки.
class_name TerminalPackageNotice

## Приоритет единственной иконки: штраф, жалоба/обязательство, новое предложение.
enum Severity {
	NONE,
	INFO,
	WARNING,
	CRITICAL,
}

## Наивысший приоритет среди непрочитанных событий.
var severity: Severity = Severity.NONE
## Все известные event IDs, включая прочитанные; только severity/text фильтруются по прочтению.
var event_ids: PackedStringArray = []
## Доступные формулировки для tooltip и клавиатурной навигации.
var text: String = ""
