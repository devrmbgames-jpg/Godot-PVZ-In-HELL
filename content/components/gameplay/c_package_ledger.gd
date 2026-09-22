extends Component
class_name C_PackageLedger

@export var records: Array[PackageRegistration] = []


func sort_records() -> void :
	records.sort_custom(
		func(a: PackageRegistration, b: PackageRegistration) -> bool :
			return a.number < b.number
	)

func has_package_with_number(number: int) -> bool :
	return records.any(
		func(a: PackageRegistration) -> bool :
			return a.number == number
	)
	
