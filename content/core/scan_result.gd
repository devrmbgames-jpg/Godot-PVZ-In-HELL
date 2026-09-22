extends RefCounted
class_name ScanResult

enum Outcome {
	REJECTED,
	REGISTERED,
	ALREADY_REGISTERED,
}

var outcome: Outcome = Outcome.REJECTED
var package_id: String = ""
var number: int = 0
var message: String = "Нет доступной посылки"
