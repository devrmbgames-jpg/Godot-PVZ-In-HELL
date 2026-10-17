@tool
extends DEF_InteractionAction
## Авторская action Definition: запрашивает native UI живого торговца в часы работы.
class_name DEF_TraderAction


## Проверяет участников, торговую роль, экономику и фазу.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	return (
		GrabQueries.holder_available(actor) and GrabQueries.holder_available(source)
		and not actor.has_component(C_Death) and not source.has_component(C_Death)
		and source.has_component(C_Trader) and cycle != null
		and TraderCatalogRules.is_open(source.get_component(C_Trader) as C_Trader, cycle)
		and CommerceService.current() != null
	)


## Повторно проверяет доступность и dispatch UI request; void не подтверждает создание панели.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if is_available(actor, source, target):
		ECS.world.emit_event(
			CommercePanelOpenRequest.EVENT,
			source,
			CommercePanelOpenRequest.new(actor, source),
		)
