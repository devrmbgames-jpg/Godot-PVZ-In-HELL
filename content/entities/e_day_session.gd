@tool
extends Entity
class_name E_DaySession


func define_components() -> Array:
	return [C_PackageLedger.new()]
