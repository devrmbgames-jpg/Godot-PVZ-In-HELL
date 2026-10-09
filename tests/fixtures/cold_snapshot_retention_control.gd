extends RefCounted
## Compile-only control with the same solvers/customer service and no snapshot dependency.


#region Compilation dependencies
func _inspect_dependencies() -> void:
	var cargo_solver: Script = CartCargoSolver
	var grab_solver: Script = GrabPhysicsSolver
	var inspection_service: Script = CustomerInspectionService
	assert(cargo_solver != null and grab_solver != null and inspection_service != null)
#endregion
