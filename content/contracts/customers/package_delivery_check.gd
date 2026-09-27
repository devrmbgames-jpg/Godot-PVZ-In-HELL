extends RefCounted
class_name PackageDeliveryCheck

enum Result { READY, MISSING, MULTIPLE, UNREGISTERED, WRONG_PACKAGE, UNASSIGNED, DESTROYED, HELD, ALREADY_CLOSED }

var result: Result = Result.MISSING
var damaged: bool = false
var opened: bool = false
