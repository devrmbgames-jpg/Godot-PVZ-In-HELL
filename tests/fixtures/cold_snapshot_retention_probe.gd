extends RefCounted
## Compile-only reproduction of shutdown retention; the method is deliberately never invoked.


#region Compilation dependencies
func _inspect_dependencies() -> void:
	var cargo_solver: Script = CartCargoSolver
	var grab_solver: Script = GrabPhysicsSolver
	var inspection_service: Script = CustomerInspectionService
	assert(cargo_solver != null and grab_solver != null and inspection_service != null)

	var snapshot: Dictionary = WorldSnapshotService.capture(null, 1)
	assert(snapshot.is_empty())
#endregion
