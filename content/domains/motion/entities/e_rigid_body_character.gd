@tool
extends E_PhysicalCharacter
## Физический callback персонажа: захват контактов, транспорт или толкание, затем движение и взгляд.
class_name E_RigidBodyCharacter



#region Настройка физического типа
func _init() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
	assert(self as Node as RigidBody3D, "is not rigid!")


#endregion

#region Физический callback
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	ImpactCaptureSolver.capture(self, state)
	if CartDriverSolver.integrate(self, state):
		# Управление транспортом заменяет движение; взгляд сохраняется благодаря
		# согласованному с транспортом direction_look из S_PlayerIntent.
		CharacterLookSolver.integrate_forces(self, state)
		return
	if PushActorSolver.integrate(self, state):
		return

	CharacterMotionSolver.integrate_forces(self, state)
	CharacterLookSolver.integrate_forces(self, state)

#endregion
