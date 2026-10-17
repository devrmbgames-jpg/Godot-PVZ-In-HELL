@tool
extends DEF_InteractionAction
## Native NPC action открывает подтверждение скупки только у своей реальной точки.
class_name DEF_BuybackAction


#region Availability and request
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if (
		not GrabQueries.holder_available(actor) or actor.has_component(C_Death)
		or not GrabQueries.holder_available(source)
		or source.has_component(C_Death) or CommerceService.current() == null
	):
		return false
	var container: E_BuybackContainer = BuybackQueries.container_for(source)
	if container == null:
		return false
	var state: C_Buyback = container.get_component(C_Buyback) as C_Buyback
	return BuybackQueries.unavailable_reason(state, source, DayPhaseQueries.current()).is_empty()


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if not is_available(actor, source, target):
		return
	ECS.world.emit_event(
		BuybackPanelOpenRequest.EVENT,
		source,
		BuybackPanelOpenRequest.new(actor, BuybackQueries.container_for(source)),
	)
#endregion
