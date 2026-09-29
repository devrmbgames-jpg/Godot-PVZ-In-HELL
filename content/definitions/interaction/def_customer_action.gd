extends DEF_InteractionAction
class_name DEF_CustomerAction


func is_available(_actor: Entity, source: Entity, _target: Entity) -> bool:
	if not source.has_component(C_CustomerAgent):
		return false
	var agent: C_CustomerAgent = source.get_component(C_CustomerAgent) as C_CustomerAgent
	return agent.phase == C_CustomerAgent.Phase.WAITING or agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerDialogueService.start(actor, source as E_Customer)
